package Genome::Model::Command::Services::SummarizeOutstandingBuilds;

use strict;
use warnings;
use Genome;
use Date::Calc qw(Delta_DHMS);

class Genome::Model::Command::Services::SummarizeOutstandingBuilds{
    is => 'Command',
    has => [
        take_action => {
            is => 'Boolean',
            is_input => 1,
            default => 0,
            doc => 'Currently disabled.  Takes appropriate action for each group of models or builds if true.  Otherwise only prints out a report',
        },
    ],
};

sub help_brief {
    #TODO: write me
    return "";
}

sub help_synopsis{
    #TODO: write me
    return "";
}

sub help_detail {
    #TODO: write me
    return "";
}

sub execute {
    my $self = shift;

    my $lock_resource = '/gsc/var/lock/genome_model_command_services_summarize-outstanding-builds/loader';
    my $lock = Genome::Sys->lock_resource(resource_lock=>$lock_resource, max_try=>1);
    unless ($lock){
        $self->error_message("could not lock, another instance must be running.");
        return;
    }

    $self->initialize_buckets;

    my @models = $self->get_models;
    $self->status_message("Done getting models");
    for my $model (@models){
        $self->separate_models_for_processing($model);
    }
    $self->status_message("Done separating models");

    $self->process_buckets;

    Genome::Sys->unlock_resource(resource_lock =>$lock);
 
    return 1;
}


sub get_models {
    my $self = shift;
    return ($self->get_models_with_unsucceeded_builds, $self->get_models_with_no_builds);
}

sub get_models_with_unsucceeded_builds {
    my $self = shift;
    #The events get here is a to try and avoid an n+1 problem with these data structures.  As of early March 2011, it doesn't work, and makes this slow as hell.
    my @events = Genome::Model::Event->get(event_type => 'genome model build', 'event_status ne' => 'Succeeded');
    my @builds = Genome::Model::Build->get('status ne' => 'Succeeded', -hint => ['model', 'the_master_event']);

    my %models;

    for my $build (@builds){
        $models{$build->model->id} = $build->model; 
    }

    return values %models;
}

sub get_models_with_no_builds {
    my $self = shift;
    my %models_without_builds;
    my @models = Genome::Model->get(-hint => ['builds']);

    for my $model (@models){
        my @builds = $model->builds;
        unless(@builds){
            $models_without_builds{$model->id} = $model;
        }
    }

    return values %models_without_builds;
}

sub process_buckets {
    my $self = shift;
    my @buckets = $self->_bucket_names;
    for my $bucket (@buckets){
        my $method_name = "_process" . $bucket;
        $self->$method_name;
    }
}

sub separate_models_for_processing {
    my ($self, $model) = @_;
    my $latest_build = $model->latest_build;
    if (not $latest_build){
        $self->separate_model_with_no_builds($model);            
    }elsif($latest_build->status eq 'Scheduled'){
        $self->separate_model_with_scheduled_build($model, $latest_build);
    }elsif($latest_build->status eq 'Running'){
        $self->separate_model_with_running_build($model, $latest_build);
    }elsif($latest_build->status eq 'Succeeded'){
        $self->separate_model_with_succeeded_build($model, $latest_build);
    }elsif($latest_build->status eq 'Abandoned'){
        $self->separate_model_with_abandoned_build($model, $latest_build);
    }elsif($latest_build->status eq 'Failed' or $latest_build->status eq 'Crashed'){
        $self->separate_model_with_failed_build($model, $latest_build);
    }elsif($latest_build->status eq 'Preserved'){
        $self->separate_model_with_preserved_build($model, $latest_build);
    }else{
        $self->warning_message("I dunno what to do with model " . $model->id);
    }
}

sub separate_model_with_no_builds{
    my $self = shift;
    my $model = shift;
    my $model_age = $self->_age_in_days($model->creation_date);
    if($model_age > 7){
        push(@{$self->_none_kill_and_email_user}, $model);
    }elsif($model_age > 3){
        push(@{$self->_none_email_user}, $model);
    }
}

sub separate_model_with_scheduled_build{
    my ($self, $model, $latest_build) = @_;
    # my $latest_build_id = $latest_build->id;
    # my $lsf_job_id = $latest_build->the_master_event->lsf_job_id;
    
    # my $bjobs_output = `bjobs $lsf_job_id`;
    # if(not $bjobs_output or not ($bjobs_output =~ m/$latest_build_id/)){
        # push(@{$self->_scheduled_incorrect_state}, $latest_build); 
    # }
#TODO: replace this with something that works.  lsf_job_id isn't useful if the build is scheduled
}

sub separate_model_with_running_build{
    my ($self, $model, $latest_build) = @_;

    my $latest_build_id = $latest_build->id;
    my $job_id;
    my $workflow = $latest_build->newest_workflow_instance;
    $job_id = $workflow->current->dispatch_identifier unless ($job_id || !$workflow);
    $job_id = $latest_build->the_master_event->lsf_job_id unless ($job_id);
    my $bjobs_output = `bjobs $job_id`;
    if(not $bjobs_output or not ($bjobs_output =~ m/$latest_build_id/)){
        push(@{$self->_running_incorrect_state}, $latest_build); 
        return;
    }

    my ($model_age) = $self->_age_in_days($latest_build->date_scheduled);
    if($model_age >=10){
        push(@{$self->_running_kill_and_email_user}, $latest_build);
    }elsif($model_age >= 3){
        push(@{$self->_running_email_user}, $latest_build);
    }
}

sub separate_model_with_succeeded_build{
    my ($self, $model, $latest_build) = @_;
    my @builds = $model->builds;
    for my $build (@builds){
        next if $build == $latest_build;
        if ($build->status eq 'Failed'){
            push (@{$self->_succeeded_abandon_builds}, $build);
        }elsif ($build->status eq 'Succeeded'){
            push (@{$self->_succeeded_eviscerate_builds}, $build);
        }elsif ($build->status eq 'Running' and $self->_age_in_days($latest_build->date_completed) >= 1){
            push(@{$self->_succeeded_kill_running_builds}, $build) if $self->_age_in_days($build->date_scheduled);
        }
    }
}

sub separate_model_with_abandoned_build{
    my ($self, $model, $latest_build) = @_;
    push(@{$self->_abandoned_start_new_builds}, $model);
}

sub separate_model_with_failed_build{
    my ($self, $model, $latest_build) = @_;
    my @builds = $model->builds;

    if(scalar(@builds) > 2 and ($builds[-2]->status eq 'Failed' or $builds[-2]->status eq 'Crashed')){
        #flag model for manual attention if the last two builds are failures
        push(@{$self->_failed_flag_for_manual_attention}, $model);
    }
    else{
        push(@{$self->_failed_start_new_builds}, $model);
    }
}

sub separate_model_with_preserved_build{
    my ($self, $model, $latest_build) = @_;
    #TODO: what do we do?  
    push(@{$self->_preserved}, $model);
}

sub initialize_buckets {
    my $self = shift;
    for my $bucket ($self->_bucket_names){
        $self->$bucket([]);
    }
    
    return 1;
}

sub _process_none_email_user{
    my $self = shift;
    if($self->take_action){
        #TODO: iterate the bucket and take appropriate action 
    }

    print "E-MAIL FOR MODEL WITH NO BUILDS\n";
    for my $model (@{$self->_none_email_user}){
        print join("\t", $model->id, $model->creation_date), "\n"; 
    }
}

sub _process_none_kill_and_email_user{
    my $self = shift;
    if($self->take_action){
        #TODO: iterate the bucket and take appropriate action 
    }

    print "KILL AND E-MAIL FOR MODEL WITH NO BUILDS\n";
    for my $model (@{$self->_none_kill_and_email_user}){
        print join("\t", $model->id, $model->creation_date), "\n"; 
    }
}

sub _process_scheduled_incorrect_state {
    my $self = shift;
    if($self->take_action){
        #TODO: iterate the bucket and take appropriate action 
    }

    print "SCHEDULED BUILDS IN INCORRECT STATE\n";
    for my $build (@{$self->_scheduled_incorrect_state}){
        print join("\t", $build->model->id, $build->id, $build->date_scheduled, $build->status), "\n"; 
    }
}

sub _process_running_incorrect_state{
    my $self = shift;
    if($self->take_action){
        #TODO: iterate the bucket and take appropriate action 
    }

    print "RUNNING BUILDS IN INCORRECT STATE\n";
    for my $build (@{$self->_running_incorrect_state}){
        print join("\t", $build->model->id, $build->id, $build->date_scheduled, $build->status), "\n"; 
    }
}

sub _process_running_email_user{
    my $self = shift;
    if($self->take_action){
        #TODO: iterate the bucket and take appropriate action 
    }

    print "EMAIL ABOUT RUNNING BUILDS 3-9 DAYS OLD\n";
    for my $build (@{$self->_running_email_user}){
        print join("\t", $build->model->id, $build->id, $build->date_scheduled, $build->status), "\n"; 
    }
}

sub _process_running_kill_and_email_user{
    my $self = shift;
    if($self->take_action){
        #TODO: iterate the bucket and take appropriate action 
    }

    print "KILL AND EMAIL ABOUT RUNNING BUILDS 10+ DAYS OLD\n";
    for my $build (@{$self->_running_kill_and_email_user}){
        print join("\t", $build->model->id, $build->id, $build->date_scheduled, $build->status), "\n"; 
    }
}

sub _process_succeeded_abandon_builds{
    my $self = shift;
    if($self->take_action){
        #TODO: iterate the bucket and take appropriate action 
    }

    print "SUCCEEDED BUILD WITH OLD FAILED BUILD TO ABANDON\n";
    for my $build (@{$self->_succeeded_abandon_builds}){
        print join("\t", $build->model->id, $build->id, $build->date_scheduled, $build->status), "\n"; 
    }
}

sub _process_succeeded_eviscerate_builds{
    my $self = shift;
    if($self->take_action){
        #TODO: iterate the bucket and take appropriate action 
    }

    print "SUCCEEDED BUILD WITH OLD SUCCEEDED BUILD TO EVISCERATE\n";
    for my $build (@{$self->_succeeded_eviscerate_builds}){
        print join("\t", $build->model->id, $build->id, $build->date_scheduled, $build->status), "\n"; 
    }
}

sub _process_succeeded_kill_running_builds{
    my $self = shift;
    if($self->take_action){
        #TODO: iterate the bucket and take appropriate action 
    }

    print "SUCCEEDED BUILD WITH OLD RUNNING BUILD TO KILL\n";
    for my $build (@{$self->_succeeded_kill_running_builds}){
        print join("\t", $build->model->id, $build->id, $build->date_scheduled, $build->status), "\n"; 
    }
}

sub _process_abandoned_start_new_builds{
    my $self = shift;
    if($self->take_action){
        #TODO: iterate the bucket and take appropriate action 
    }

    print "START BUILD ON MODEL WITH ABANDONED BUILD\n";
    for my $model (@{$self->_abandoned_start_new_builds}){
        print join("\t", $model->id, $model->creation_date), "\n"; 
    }
}

sub _process_failed_start_new_builds{
    my $self = shift;
    if($self->take_action){
        #TODO: iterate the bucket and take appropriate action 
    }

    print "START BUILD ON MODEL WITH SINGLE FAILED BUILD\n";
    for my $model (@{$self->_failed_start_new_builds}){
        print join("\t", $model->id, $model->creation_date), "\n"; 
    }
}

sub _process_failed_flag_for_manual_attention{
    my $self = shift;
    if($self->take_action){
        #TODO: iterate the bucket and take appropriate action 
    }

    print "FLAG MODEL WITH TWO FAILED BUILDS IN A ROW FOR MANUAL ATTENTION\n";
    for my $model (@{$self->_failed_flag_for_manual_attention}){
        print join("\t", $model->id, $model->creation_date), "\n"; 
    }
}

sub _process_preserved {
    my $self = shift;
    if($self->take_action){
        #TODO: iterate the bucket and take appropriate action 
    }

    print "IGNORE MODEL WITH PRESERVED BUILD\n";
    for my $model (@{$self->_preserved}){
        print join("\t", $model->id, $model->creation_date), "\n"; 
    }
}

sub _age_in_days {
    my ($self, $date) = @_;
    my ($age_in_days) = Delta_DHMS(split("-|:| ", $date), split("-|:| ",$self->__context__->now));
    return $age_in_days;
}

sub _bucket_names{
    my @buckets = qw(_none_email_user _none_kill_and_email_user _scheduled_incorrect_state _running_incorrect_state _running_email_user _running_kill_and_email_user _succeeded_abandon_builds _succeeded_eviscerate_builds _succeeded_kill_running_builds _abandoned_start_new_builds _failed_start_new_builds _failed_flag_for_manual_attention _preserved);
    return @buckets;
}

sub _none_email_user {
    my ($self, $hash_ref) = @_;
    $self->{_none_email_user} = $hash_ref if $hash_ref;
    return $self->{_none_email_user};
}

sub _none_kill_and_email_user {
    my ($self, $hash_ref) = @_;
    $self->{_none_kill_and_email_user} = $hash_ref if $hash_ref;
    return $self->{_none_kill_and_email_user};
}

sub _scheduled_incorrect_state {
    my ($self, $hash_ref) = @_;
    $self->{_scheduled_incorrect_state} = $hash_ref if $hash_ref;
    return $self->{_scheduled_incorrect_state};
}


sub _running_incorrect_state {
    my ($self, $hash_ref) = @_;
    $self->{_running_incorrect_state} = $hash_ref if $hash_ref;
    return $self->{_running_incorrect_state};
}

sub _running_email_user {
    my ($self, $hash_ref) = @_;
    $self->{_running_email_user} = $hash_ref if $hash_ref;
    return $self->{_running_email_user};
}

sub _running_kill_and_email_user {
    my ($self, $hash_ref) = @_;
    $self->{_running_kill_and_email_user} = $hash_ref if $hash_ref;
    return $self->{_running_kill_and_email_user};
}

sub _succeeded_abandon_builds {
    my ($self, $hash_ref) = @_;
    $self->{_succeeded_abandon_builds} = $hash_ref if $hash_ref;
    return $self->{_succeeded_abandon_builds};
}

sub _succeeded_eviscerate_builds {
    my ($self, $hash_ref) = @_;
    $self->{_succeeded_eviscerate_builds} = $hash_ref if $hash_ref;
    return $self->{_succeeded_eviscerate_builds};
}

sub _succeeded_kill_running_builds {
    my ($self, $hash_ref) = @_;
    $self->{_succeeded_kill_running_builds} = $hash_ref if $hash_ref;
    return $self->{_succeeded_kill_running_builds};
}

sub _abandoned_start_new_builds {
    my ($self, $hash_ref) = @_;
    $self->{_abandoned_start_new_builds} = $hash_ref if $hash_ref;
    return $self->{_abandoned_start_new_builds};
}

sub _failed_start_new_builds {
    my ($self, $hash_ref) = @_;
    $self->{_failed_start_new_builds} = $hash_ref if $hash_ref;
    return $self->{_failed_start_new_builds};
}

sub _failed_flag_for_manual_attention {
    my ($self, $hash_ref) = @_;
    $self->{_failed_flag_for_manual_attention} = $hash_ref if $hash_ref;
    return $self->{_failed_flag_for_manual_attention};
}

sub _preserved{
    my ($self, $hash_ref) = @_;
    $self->{_preserved} = $hash_ref if $hash_ref;
    return $self->{_preserved};
}
