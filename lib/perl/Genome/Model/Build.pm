package Genome::Model::Build;

use strict;
use warnings;

use Genome;

use Carp;
use Data::Dumper 'Dumper';
use File::Path;
use File::Find 'find';
use File::Basename qw/ dirname fileparse /;
use Regexp::Common;
use Workflow;
use YAML;

class Genome::Model::Build {
    type_name => 'genome model build',
    table_name => 'GENOME_MODEL_BUILD',
    is_abstract => 1,
    subclassify_by => 'subclass_name',
    id_by => [
        build_id => { is => 'NUMBER', len => 10 },
    ],
    has => [
        subclass_name           => { is => 'VARCHAR2', len => 255, is_mutable => 0, column_name => 'SUBCLASS_NAME',
                                     calculate_from => ['model_id'],
                                     # We subclass via our model's type_name (which is via it's processing profile's type_name)
                                     calculate => sub {
                                                      my($model_id) = @_;
                                                      return unless $model_id;
                                                      my $model = Genome::Model->get($model_id);
                                                      Carp::croak("Can't find Genome::Model with ID $model_id while resolving subclass for Build") unless $model;
                                                      return __PACKAGE__ . '::' . Genome::Utility::Text::string_to_camel_case($model->type_name);
                                                  }
                                   },
        data_directory          => { is => 'VARCHAR2', len => 1000, is_optional => 1 },
        model                   => { is => 'Genome::Model', id_by => 'model_id' },
        model_id                => { is => 'NUMBER', len => 10, implied_by => 'model', constraint_name => 'GMB_GMM_FK' },
        model_name              => { via => 'model', to => 'name' },
        type_name               => { via => 'model' },
        subject_id              => { via => 'model' },
        subject_name            => { via => 'model' },
        processing_profile      => { via => 'model' },
        processing_profile_name => { via => 'model' },
        the_events              => { is => 'Genome::Model::Event', reverse_as => 'build', is_many => 1 },
        the_events_statuses     => { via => 'the_events', to => 'event_status' },
        the_master_event        => { is => 'Genome::Model::Event', reverse_as => 'build', where => [ event_type => 'genome model build' ], is_many => 1, is_constant => 1},
        run_by                  => { via => 'the_master_event', to => 'user_name' },
        status                  => { via => 'the_master_event', to => 'event_status', is_mutable => 1 },
        date_scheduled          => { via => 'the_master_event', to => 'date_scheduled', },
        date_completed          => { via => 'the_master_event', to => 'date_completed' },
        master_event_status     => { via => 'the_master_event', to => 'event_status' },
    ],
    has_optional => [
        disk_allocation   => { is => 'Genome::Disk::Allocation', calculate_from => [ 'class', 'id' ],
                               calculate => q(
                                    my $disk_allocation = Genome::Disk::Allocation->get(
                                                          owner_class_name => $class,
                                                          owner_id => $id,
                                                      );
                                    return $disk_allocation;
                                ) },
        software_revision => { is => 'VARCHAR2', len => 1000 },
    ],
    has_many_optional => [
        inputs           => { is => 'Genome::Model::Build::Input', reverse_as => 'build', 
                              doc => 'Inputs assigned to the model when the build was created.' },
        instrument_data  => { is => 'Genome::InstrumentData', via => 'inputs', to => 'value', is_mutable => 1, where => [ name => 'instrument_data' ], 
                              doc => 'Instrument data assigned to the model when the build was created.' },
        from_build_links => { is => 'Genome::Model::Build::Link', reverse_as => 'to_build', 
                              doc => 'bridge table entries where this is the \"to\" build(used to retrieve builds this build is \"from\")' },
        from_builds      => { is => 'Genome::Model::Build', via => 'from_build_links', to => 'from_build', 
                              doc => 'Genome builds that contribute \"to\" this build' },
        to_build_links   => { is => 'Genome::Model::Build::Link', reverse_as => 'from_build', 
                              doc => 'bridge entries where this is the \"from\" build(used to retrieve builds builds this build is \"to\")' },
        to_builds        => { is => 'Genome::Model::Build', via => 'to_build_links', to => 'to_build', 
                              doc => 'Genome builds this build contributes \"to\"' },
        attributes       => { is => 'Genome::MiscAttribute', reverse_as => '_build', where => [ entity_class_name => 'Genome::Model::Build' ] },
        metrics          => { is => 'Genome::Model::Metric', reverse_as => 'build', 
                              doc => 'Build metrics' },
        variants         => { is => 'Genome::Model::BuildVariant', reverse_as => 'build', 
                              doc => 'variants linked to this build... currently only for Somatic builds but need this accessor for get_all_objects' },
        group_ids        => { via => 'model', to => 'group_ids', is_many => 1, },
        group_names      => { via => 'model', to => 'group_names', is_many => 1, },

        projects         => { is => 'Genome::Site::WUGC::Project', via => 'model' },
        work_orders      => { is => 'Genome::WorkOrder', via => 'projects' },
        work_order_names => { via => 'work_orders', to => 'name' },
        work_order_numbers => { via => 'work_orders', to => 'id' },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

sub __display_name__ {
    my $self = shift;
    return $self->id . ' of ' . $self->model->name;
}

sub _resolve_subclass_name_by_sequencing_platform { # only temporary, subclass will soon be stored
    my $class = shift;

    Carp::confess("this is used by sub-classes which further subclassify by sequencing platform!")
        if $class eq __PACKAGE__;

    my $sequencing_platform;
    if (ref($_[0]) and $_[0]->isa('Genome::Model::Build')) {
        $sequencing_platform = $_[0]->model->sequencing_platform;
    } 
    else {
        my %params;
        if (ref($_[0]) and $_[0]->isa("UR::BoolExpr")) {
            %params = $_[0]->params_list;
        }
        else {
            %params = @_;
        }
        my $model_id = $params{model_id};
        $class->_validate_model_id($params{model_id})
            or return;
        my $model = Genome::Model->get($params{model_id});
        unless ( $model ) {
            Carp::confess("Can't get model for id: .".$params{model_id});
        }
        $sequencing_platform = $model->sequencing_platform;
    }

    return unless $sequencing_platform;

    return $class. '::'.Genome::Utility::Text::string_to_camel_case($sequencing_platform);
}

# auto generate sub-classes for any valid processing profile
sub __extend_namespace__ {
    my ($self,$ext) = @_;

    my $meta = $self->SUPER::__extend_namespace__($ext);
    return $meta if $meta;
    
    my $pp_subclass_name = 'Genome::ProcessingProfile::' . $ext;
    my $pp_subclass_meta = UR::Object::Type->get($pp_subclass_name);
    if ($pp_subclass_meta and $pp_subclass_name->isa('Genome::ProcessingProfile')) {
        my $build_subclass_name = 'Genome::Model::Build::' . $ext;
        my $build_subclass_meta = UR::Object::Type->define(
            class_name => $build_subclass_name,
            is => 'Genome::Model::Build',
        );
        die "Error defining $build_subclass_name for $pp_subclass_name!" unless $build_subclass_meta;
        return $build_subclass_meta;
    }
    return;
}

sub create {
    my $class = shift;
    if ($class eq __PACKAGE__ or $class->__meta__->is_abstract) {
        # let the base class re-call the constructor from the correct sub-class
        return $class->SUPER::create(@_);
    }

    my $bx = $class->define_boolexpr(@_);
    my $model_id = $bx->value_for('model_id');

    # model
    return unless ($class->_validate_model_id($model_id));

    #unless ($bx->value_for('subclass_name')) {
    #    $bx = $bx->add_filter(subclass_name => $class);
    #}

    # create
    my $self = $class->SUPER::create($bx);
    return unless $self;

    # instrument data assignments - set first build id
    my @ida = $self->model->instrument_data_assignments;
    for my $ida ( @ida ) {
        next if defined $ida->first_build_id;
        $ida->first_build_id( $self->id )
    }
    
    # inputs
    unless ( $self->_copy_model_inputs ) {
        $self->delete;
        return;
    }

    # data directory
    unless ($self->data_directory) {
        my $dir;
        eval {
            $dir = $self->resolve_data_directory;
        };
        if ($@) {
            $self->error_message("Failed to resolve a data directory for a new build!: $@");
            $self->delete;
            return;
        }
        $self->data_directory($dir);
    }

    my $processing_profile = $self->processing_profile;
    unless ($processing_profile->_initialize_build($self)) {
        $class->error_message($processing_profile->error_message);
        $self->delete;
        return;
    }

    my $data_directory_undo =  sub {
        if ($self->data_directory && -e $self->data_directory) {
            if (rmtree($self->data_directory, { error => \my $remove_errors })) {
                $self->status_message("Removed build's data directory (" . $self->data_directory . ").");
            }
            else {
                if (@$remove_errors) {
                    my $error_summary;
                    for my $error (@$remove_errors) {
                        my ($file, $error_message) = %$error;
                        if ($file eq '') {
                            $error_summary .= "General error removing build directory: $error_message\n";
                        }
                        else {
                            $error_summary .= "Error removing file $file : $error_message\n";
                        }
                    }
                    $self->error_message($error_summary);
                }

                confess "Failed to remove build directory tree at " . $self->data_directory . ", cannot remove build!";
            }
        }
    };
    my $data_directory_change = UR::Context::Transaction->log_change($self, 'UR::Value', $self->data_directory, 'external_change', $data_directory_undo);
    if ($data_directory_change) {
        $self->status_message("Recorded creation of data directory (" . $self->data_directory . ").");
    }
    else {
        die $self->error_message("Failed to record creation of data directory (" . $self->data_directory . ").");
    }

    my $disk_allocation = $self->disk_allocation;
    if ($disk_allocation) {
        my $allocation_undo = sub {
            unless ($disk_allocation->deallocate) {
                $self->warning_message('Failed to deallocate disk space.');
            }
        };
        my $allocation_change = UR::Context::Transaction->log_change($self, 'UR::Value', $self->disk_allocation->id, 'external_change', $allocation_undo);
        if ($allocation_change) {
            $self->status_message("Recorded creation of disk allocation (" . $self->disk_allocation->id . ")");
        }
        else {
            die $self->error_message("Failed to record creation of disk allocation (" . $self->disk_allocation->id . ")");
        }
    }   

    return $self;
}

sub _validate_model_id {
    my ($class, $model_id) = @_;

    unless ( defined $model_id ) {
        $class->error_message("No model id given to get model of build.");
        return;
    }

    unless ( $model_id =~ /^$RE{num}{int}$/ ) {
        $class->error_message("Model id ($model_id) is not an integer.");
        return;
    }

    unless ( Genome::Model->get($model_id) ) {
        $class->error_message("Can't get model for id ($model_id).");
        return;
    }
    
    return 1;
}

sub _select_build_from_input_model {
    my ($self, $model) = @_;
    return $model->last_complete_build;
}

sub _copy_model_inputs {
    my $self = shift;

    for my $input ( $self->model->inputs ) {
        my %params = map { $_ => $input->$_ } (qw/ name value_class_name value_id /);

        # We need to turn model inputs into builds.
        if($params{value_class_name}->isa('Genome::Model')) {
            # Next if we already have a build defined (e.g., by create params).
            my $input_name = $input->name;
            next if defined $self->$input_name and $self->$input_name->isa('Genome::Model::Build');

            my $input_model = $input->value;
            my $input_build = $self->_select_build_from_input_model($input_model);

            unless($input_build) {
                $self->error_message('Failed to select a build to copy for input model ' . 
                    $input->name . '=' . $input_model->__display_name__ . 
                    '. Try specifying one.');
                return;
            }

            $params{value_class_name} = $input_build->class;
            $params{value_id} = $input_build->id;
        }

        unless ( $self->add_input(%params) ) {
            $self->error_message("Can't copy model input to build: ".Data::Dumper::Dumper(\%params));
            return;
        }
    }

    # FIXME temporary - copy model instrument data as inputs, when all 
    #  inst_data is an input, this can be removed
    my @existing_inst_data = $self->instrument_data;
    my @model_inst_data = $self->model->instrument_data;
    for my $inst_data ( @model_inst_data ) {
        # We may have added the inst data when adding the inputs
        # Adding as input cuz of mock inst data
        #print Data::Dumper::Dumper($inst_data);
        next if grep { $inst_data->id eq $_->id } @existing_inst_data;
        my %params = (
            name => 'instrument_data',
            value_class_name => $inst_data->class,
            value_id => $inst_data->id,
        );
        unless ( $self->add_input(%params) ) {
            $self->error_message("Can't add instrument data (".$inst_data->id.") to build.");
            return;
        }
    }

    return 1;

}

sub instrument_data_assignments {
    my $self = shift;
    my @idas = Genome::Model::InstrumentDataAssignment->get(
        model_id => $self->model_id,
        first_build_id => {
            operator => '<=',
            value => $self->build_id,
        },
    );
    return @idas;
}

sub instrument_data_count {
    my $self = shift;

    # Try inst data from inputs
    my @instrument_data = $self->instrument_data;
    if ( @instrument_data ) {
        return scalar(@instrument_data);
    }

    # use first build id on model's ida for older builds
    return scalar( $self->instrument_data_assignments );
}

sub events {
    my $self = shift;
    my @events = Genome::Model::Event->get(
        model_id => $self->model_id,
        build_id => $self->build_id,
    );
    return @events;
}

sub build_events {
    my $self = shift;
    my @build_events = Genome::Model::Event::Build->get(
        model_id => $self->model_id,
        build_id => $self->build_id,
    );
    return @build_events;
}

sub build_event {
    my $self = shift;
    my @build_events = $self->build_events;
    if (scalar(@build_events) > 1) {
        my $error_message = 'Found '. scalar(@build_events) .' build events for model id '.
        $self->model_id .' and build id '. $self->build_id ."\n";
        for (@build_events) {
            $error_message .= "\t". $_->desc .' '. $_->event_status ."\n";
        }
        die($error_message);
    }
    return $build_events[0];
}

sub workflow_name {
    my $self = shift;
    return $self->build_id . ' all stages';
}

sub workflow_instances {
    my $self = shift;
    my @instances = Workflow::Operation::Instance->get(
        name => $self->workflow_name,
    );
    return @instances;
}

sub newest_workflow_instance {
    my $self = shift;
    my @sorted = sort { 
        $b->id <=> $a->id
    } $self->workflow_instances;
    if (@sorted) { 
        return $sorted[0];
    } else {
        return;
    }
}

sub calculate_estimated_kb_usage {
    my $self = shift;

    # Default of 500 MiB in case a subclass fails to
    # override this method.  At least this way there
    # will be an allocation, which will likely be
    # wildly inaccurate, but if the build fails to fail,
    # when it finishes, it will reallocate down to the
    # actual size.  Whereas the previous behaviour 
    # (return undef) caused *no* allocation to be made.
    # Which it has been decided is a bigger problem.
    return 512_000;
}

# If the data directory is not set, resolving it requires making an allocation.  A build is unlikely to
# make a new allocation at any other time, so a separate build instance method for allocating is not
# provided.
sub resolve_data_directory {
    my $self = shift;
    my $model = $self->model;
    my $build_data_directory;
    my $model_data_directory = $model->data_directory;
    # TODO This check is site specific... what does it matter if the model path doesn't follow this pattern?
    my $model_path_is_abnormal = defined($model_data_directory) && $model_data_directory !~ /\/gscmnt\/.*\/info\/(?:medseq\/)?.*/;

    if($model->genome_model_id < 0 && $model_path_is_abnormal)
    {
        # The build is being created for an automated test; allocating for it would leave stray directories.
        # Rather than relying on this if statement, tests should specify a build directory.
        $build_data_directory = $model_data_directory . '/build' . $self->id;
        warn "Please update this test to set build data_directory. (generated data_directory: \"$build_data_directory\")";
        unless (Genome::Sys->create_directory($build_data_directory)) {
            $self->error_message("Failed to create directory '$build_data_directory'");
            die $self->error_message;
        }
    }
    else
    {
        if ($model_path_is_abnormal) {
            # why should this ever fail?
            warn "The model data directory \"$model_data_directory\" follows an unexpected pattern!";
        }
    
        my $allocation_path = 'model_data/' . $model->id . '/build'. $self->build_id;
        my $kb_requested = $self->calculate_estimated_kb_usage;
        unless ($kb_requested) {
            warn "No disk allocation for this build.";
            return;
        }
    
        my $disk_group_name = $model->processing_profile->_resolve_disk_group_name_for_build($self);
        unless ($disk_group_name) {
            die $self->error_message('Failed to resolve a disk group for a new build!');
        }
    
        # This is run as a shell command to ensure that a commit is executed after the allocation is created,
        # which triggers the release of disk volume locks and the creation of the allocation path.
        my $class = $self->class;
        my $id = $self->id;
        my $rv = system("genome disk allocation create --disk-group-name $disk_group_name " .
            "--allocation-path $allocation_path --kilobytes-requested $kb_requested " .
            "--owner_class_name $class --owner_id $id");
        unless (defined $rv and $rv == 0) {
            Carp::confess $self->error_message('Failed to create allocation for build');
        }

        my $disk_allocation = $self->disk_allocation;
        unless ($disk_allocation) {
            Carp::confess $self->error_message('Failed to retrieve disk allocation for build');
        }
    
        $build_data_directory = $disk_allocation->absolute_path;
        Genome::Sys->validate_existing_directory($build_data_directory);
    
        # TODO: we should stop having model directories and making build symlinks!!!
        my $build_symlink = $model_data_directory . '/build' . $self->build_id;
        unlink $build_symlink if -e $build_symlink;
        unless (Genome::Sys->create_symlink($build_data_directory,$build_symlink)) {
            $self->error_message("Failed to make symlink \"$build_symlink\" with target \"$build_data_directory\"");
            die $self->error_message;
        }
    }

    return $build_data_directory;
}

sub reallocate {
    my $self = shift;

    my $disk_allocation = $self->disk_allocation
        or return 1; # ok - may not have an allocation

    unless ($disk_allocation->reallocate) {
        $self->warning_message('Failed to reallocate disk space.');
    }

    return 1;
}

sub log_directory { 
    return  $_[0]->data_directory . '/logs/';
}

sub reports_directory { 
    return  $_[0]->data_directory . '/reports/';
}

sub resolve_reports_directory { return reports_directory(@_); } #????

sub add_report {
    my ($self, $report) = @_;

    my $directory = $self->resolve_reports_directory;
    if (-d $directory) {
        my $subdir = $directory . '/' . $report->name_to_subdirectory($report->name);
        if (-e $subdir) {
            $self->status_message("Sub-directory $subdir exists!   Moving it out of the way...");
            my $n = 1;
            my $max = 20;
            while ($n < $max and -e $subdir . '.' . $n) {
                $n++;
            }
            if ($n == $max) {
                die "Too many re-runs of this report!  Contact Informatics..."
            }
            rename $subdir, "$subdir.$n";
            if (-e $subdir) {
                die "failed to move old report dir $subdir to $subdir.$n!: $!";
            }
        }
    }
    else {
        $self->status_message("creating directory $directory...");
        unless (Genome::Sys->create_directory($directory)) {
            die "failed to make directory $directory!: $!";
        }
    }
    
    if ($report->save($directory)) {
        $self->status_message("Saved report to override directory: $directory");
        return 1;
    }
    else {
        $self->error_message("Error saving report!: " . $report->error_message());
        return;
    }
}

sub start {
    my $self = shift;
    my %params = @_;

    # TODO make it so we don't need to pass anything to init the workflow.
    my $workflow = $self->_initialize_workflow($params{job_dispatch} || 'apipe');
    unless ($workflow) {
        my $msg = $self->error_message("Failed to initialize a workflow!");
        croak $msg;
    }

#    $params{workflow} = $workflow;

    return unless $self->_launch(%params);

    #If a build has been requested, this build starting fulfills that request.
    $self->model->build_requested(0);
    return 1;
}

sub stop {
    my $self = shift;

    $self->status_message('Attempting to stop build: '.$self->id);

    my $user = getpwuid($<);
    if ($user ne 'apipe-builder' && $user ne $self->run_by) {
        $self->error_message("Can't stop a build originally started by: " . $self->run_by);
        return 0;
    }

    my $job = $self->_get_running_master_lsf_job; 
    if ( defined $job ) {
        $self->status_message('Killing job: '.$job->{Job});
        $self->_kill_job($job);
        $self = Genome::Model::Build->load($self->id);
    }

    my $self_event = $self->build_event;
    my $error = Genome::Model::Build::Error->create(
        build_event_id => $self_event->id,
        stage_event_id => $self_event->id,
        stage => 'all stages',
        step_event_id => $self_event->id,
        step => 'main',
        error => 'Killed by user',
    );

    $self->status_message('Failing build: '.$self->id);
    unless ($self->fail($error)) {
        $self->error_message('Failed to fail build');
        return;
    }

    return 1
}

sub _kill_job {
    my ($self, $job) = @_;

    Genome::Sys->shellcmd(
        cmd => 'bkill '.$job->{Job},
    );

    my $i = 0;
    do {
        $self->status_message("Waiting for job to stop") if ($i % 10 == 0);
        $i++;
        sleep 1;
        $job = $self->_get_job( $job->{Job} );

        if ($i > 60) {
            $self->error_message("Build master job did not die after 60 seconds.");
            return 0;
        }
    } while ($job && ($job->{Status} ne 'EXIT' && $job->{Status} ne 'DONE'));

    return 1;
}

sub _get_running_master_lsf_job {
    my $self = shift;

    my $job_id = $self->the_master_event->lsf_job_id;
    return if not defined $job_id;

    my $job = $self->_get_job($job_id);
    return if not defined $job;

    if ( $job->{Status} eq 'EXIT' or $job->{Status} eq 'DONE' ) {
        return;
    }

    return $job;
}

sub _get_job {
    use Genome::Model::Command::Services::Build::Scan;
    my $self = shift;
    my $job_id = shift;

    my @jobs = ();
    my $iter = Job::Iterator->new($job_id);
    while (my $job = $iter->next) {
        push @jobs, $job;
    }

    if (@jobs > 1) {
        $self->error_message("More than 1 job found for this build? Alert apipe");
        return 0;
    }

    return shift @jobs;
}

sub restart {
    my $self = shift;
    my %params = @_;

    $self->status_message('Attempting to restart build: '.$self->id);
   
    if (delete $params{job_dispatch}) {
        cluck $self->error_message('job_dispatch cannot be changed on restart');
    }
    
    my $user = getpwuid($<);
    if ($self->run_by ne $user) {
        croak $self->error_message("Can't restart a build originally started by: " . $self->run_by);
    }

    my $xmlfile = $self->data_directory . '/build.xml';
    if (!-e $xmlfile) {
        croak $self->error_message("Can't find xml file for build (" . $self->id . "): " . $xmlfile);
    }

    # Check if the build is running
    my $job = $self->_get_running_master_lsf_job;
    if ($job) {
        $self->error_message("Build is currently running. Stop it first, then restart.");
        return 0;
    }

    # Since the job is not running, check if there is server location file and rm it
    my $loc_file = $self->data_directory . '/server_location.txt';
    if ( -e $loc_file ) {
        $self->status_message("Removing server location file for dead lsf job: $loc_file");
        unlink $loc_file;
    }

    my $w = $self->newest_workflow_instance;
    if ($w && !$params{fresh_workflow}) {
        if ($w->is_done) {
            croak $self->error_message("Workflow Instance is complete");
        }
    }

    my $build_event = $self->build_event;
    if($build_event->event_status eq 'Abandoned') {
        $self->error_message("Can't restart a build that was abandoned.  Start a new build instead.");
        return 0;
    }

    $build_event->event_status('Scheduled');
    $build_event->date_completed(undef);

    for my $e ($self->the_events(event_status => ['Running','Failed'])) {
        $e->event_status('Scheduled');
    }
    
    return $self->_launch(%params);
}

sub _launch {
    my $self = shift;
    my %params = @_;

    local $ENV{UR_COMMAND_DUMP_STATUS_MESSAGES} = 1;

    # right now it is "inline" or the name of an LSF queue.
    # ultimately, it will be the specification for parallelization
    #  including whether the server is inline, forked, or bsubbed, and the
    #  jobs are inline, forked or bsubbed from the server
    my $server_dispatch;
    my $job_dispatch;
    my $model = $self->model;
    if (exists($params{server_dispatch})) {
        $server_dispatch = delete $params{server_dispatch};
    } elsif ($model->processing_profile->can('server_dispatch') && defined $model->processing_profile->server_dispatch) {
        $server_dispatch = $model->processing_profile->server_dispatch;
    } else {
        $server_dispatch = 'workflow';
    }

    if (exists($params{job_dispatch})) {
        $job_dispatch = delete $params{job_dispatch};
    } elsif ($model->processing_profile->can('job_dispatch') && defined $model->processing_profile->job_dispatch) {
        $job_dispatch = $model->processing_profile->job_dispatch;
    } else {
        $job_dispatch = 'apipe';
    }
    my $fresh_workflow = delete $params{fresh_workflow};

    my $job_group_spec;
    if (exists $params{job_group}) {
        my $job_group = delete $params{job_group};
        if ($job_group) {
            $job_group_spec = " -g $job_group";
        }
        else {
            $job_group_spec = "";
        }
    }
    else {
        my $user = getpwuid($<);
        $job_group_spec = ' -g /build2/' . $user;
    }

    die "Bad params!  Expected server_dispatch and job_dispatch!" . Data::Dumper::Dumper(\%params) if %params;

    my $build_event = $self->the_master_event;

    # TODO: send the workflow to the dispatcher instead of having LSF logic here.
    if ($server_dispatch eq 'inline') {
        # TODO: redirect STDOUT/STDERR to these files
        #$build_event->output_log_file,
        #$build_event->error_log_file,
        
        my %args = (
            model_id => $self->model_id,
            build_id => $self->id,
        );
        if ($job_dispatch eq 'inline') {
            $args{inline} = 1;
        }
        
        my $rv = Genome::Model::Command::Services::Build::Run->execute(%args);
        return $rv;
    }
    else {
        my $add_args = ($job_dispatch eq 'inline') ? ' --inline' : '';
        if ($fresh_workflow) {
            $add_args .= ' --restart';
        }

        my $host_group = `bqueues -l $server_dispatch | grep ^HOSTS:`;
        chomp $host_group;
        $host_group =~ s/^HOSTS:\s+//;
        $host_group =~ s/\///g;
        $host_group =~ s/\s+$//g;
        $host_group = "-m '$host_group'";

        my $lsf_project = "build" . $self->id;

        # bsub into the queue specified by the dispatch spec
        my $user = getpwuid($<);
        my $lsf_command = sprintf(
            'bsub -P %s -N -H -q %s %s %s -u %s@genome.wustl.edu -o %s -e %s annotate-log genome model services build run%s --model-id %s --build-id %s',
            $lsf_project,
            $server_dispatch, ## lsf queue
            $host_group,
            $job_group_spec,
            $user, 
            $build_event->output_log_file,
            $build_event->error_log_file,
            $add_args,
            $model->id,
            $self->id,
        );
        print $lsf_command."\n";
    
    

        # lock model
        my $model_id = $self->model->id;
        my $lock_id = '/gsc/var/lock/build_start/'.$model_id;
        my $lock = Genome::Sys->lock_resource(
            resource_lock => $lock_id, 
            block_sleep => 3,
            max_try => 3,
        );
        if ($lock) {
            $self->status_message("Locked model ($model_id) while launching " . $self->__display_name__ . ".");
        }
        else {
            print STDERR "Failed to get build start lock for model $model_id. This means someone|thing else is attempting to build this model. Please wait a moment, and try again. If you think that this model is incorrectly locked, please put a ticket into the apipe support queue.";
            return;
        }

        my $job_id = $self->_execute_bsub_command($lsf_command);
        unless ($job_id) {
            Genome::Sys->lock_resource(resource_lock => $lock) if ($lock);
            return;
        }
        
        # create a commit observer to resume the job when build is committed to database
        my $commit_observer = $build_event->add_observer(
            aspect => 'commit',
            callback => sub {
                $self->status_message("Resuming LSF job ($job_id) for build " . $self->__display_name__ . ".");
                my $bresume_output = `bresume $job_id`; chomp $bresume_output;
                unless ( $bresume_output =~ /^Job <$job_id> is being resumed$/ ) {
                    $self->status_message($bresume_output);
                }
                Genome::Sys->unlock_resource(resource_lock => $lock_id);
            }
        );
        if ($commit_observer) {
            $self->status_message("Added commit observer to resume LSF job ($job_id).");
        }
        else {
            $self->error_message("Failed to add commit observer to resume LSF job ($job_id).");
        }

        $build_event->lsf_job_id($job_id);


        return 1;
    }
}

sub _initialize_workflow {
    my $self = shift;
    my $lsf_queue_eliminate_me = shift || 'apipe';

    Genome::Sys->create_directory( $self->data_directory )
        or return;

    Genome::Sys->create_directory( $self->log_directory )
        or return;

    if ( my $existing_build_event = $self->build_event ) {
        $self->error_message(
            "Can't schedule this build (".$self->id."), it a already has a main build event: ".
            Data::Dumper::Dumper($existing_build_event)
        );
        return;
    }

    $self->software_revision(UR::Util::used_libs_perl5lib_prefix());

    my $build_event = Genome::Model::Event::Build->create(
        model_id => $self->model->id,
        build_id => $self->id,
        event_type => 'genome model build',
    );

    unless ( $build_event ) {
        $self->error_message( 
            sprintf("Can't create build for model (%s %s)", $self->model->id, $self->model->name) 
        );
        $self->delete;
        return;
    }

    $build_event->schedule; # in G:M:Event, sets status, times, etc.

    my $model = $self->model;
    my $processing_profile = $self->processing_profile;

    my $workflow = $processing_profile->_resolve_workflow_for_build($self,$lsf_queue_eliminate_me);

    ## so developers dont fail before the workflow changes get deployed to /gsc/scripts
    if ($workflow->can('notify_url')) {
        require UR::Object::View::Default::Xsl;

        my $cachetrigger = Genome::Config->base_web_uri;
        $cachetrigger =~ s/view$/cachetrigger/;

        my $url = $cachetrigger . '/' . UR::Object::View::Default::Xsl::type_to_url(ref($self)) . '/status.html?id=' . $self->id;
        $url .= ' ' . $cachetrigger . '/workflow/operation/instance/statuspopup.html?id=[WORKFLOW_ID]';

        $workflow->notify_url($url);
    }
    $workflow->save_to_xml(OutputFile => $self->data_directory . '/build.xml');
    
    return $workflow;
}

sub _execute_bsub_command { # here to overload in testing
    my ($self, $cmd) = @_;

    local $ENV{UR_COMMAND_DUMP_STATUS_MESSAGES} = 1;

    if ($ENV{UR_DBI_NO_COMMIT}) {
        $self->warning_message("Skipping bsub when NO_COMMIT is turned on (job will fail)\n$cmd");
        return 1;
    }

    my $bsub_output = `$cmd`;

    my $rv = $? >> 8;
    if ( $rv ) {
        $self->error_message("Failed to launch bsub (exit code: $rv) command:\n$bsub_output");
        return;
    }

    if ( $bsub_output =~ m/Job <(\d+)>/ ) {
        my $job_id = $1;

        # create a change record so that if it is "undone" it will kill the job
        my $bsub_undo = sub {
            $self->status_message("Killing LSF job ($job_id) for build " . $self->__display_name__ . ".");
            system("bkill $job_id");
        };
        my $lsf_change = UR::Context::Transaction->log_change($self, 'UR::Value', $job_id, 'external_change', $bsub_undo);
        if ($lsf_change) {
            $self->status_message("Recorded LSF job submission ($job_id).");
        }
        else {
            die $self->error_message("Failed to record LSF job submission ($job_id).");
        }

        return "$job_id";
    } 
    else {
        $self->error_message("Launched busb command, but unable to parse bsub output: $bsub_output");
        return;
    }
}


sub initialize {
    my $self = shift;

    $self->_verify_build_is_not_abandoned_and_set_status_to('Running')
        or return;
   
    $self->generate_send_and_save_report('Genome::Model::Report::BuildInitialized')
        or return;

    return 1;
}

sub fail {
    my ($self, @errors) = @_;

    # reload all the events
    my @e = Genome::Model::Event->load(build_id => $self->build_id);

    $self->_verify_build_is_not_abandoned_and_set_status_to('Failed', 1)
        or return;

    # set event status
    for my $e ($self->the_events(event_status => 'Running')) {
        $e->event_status('Failed');
    }

    $self->generate_send_and_save_report(
        'Genome::Model::Report::BuildFailed', {
            errors => \@errors,
        },
    )
        or return;
    
    # FIXME Don't know if this should go here, but then we would have to call success and abandon through the model
    my $last_complete_build = $self->model->resolve_last_complete_build;
    if ( $last_complete_build and $last_complete_build->id eq $self->id ) {
        $self->error_message("Tried to resolve last complete build for model (".$self->model_id."), which should not return this build (".$self->id."), but did.");
        # FIXME soon - return here
        # return;
    }
    
    return 1;
}

sub success {
    my $self = shift;

    # reload all the events
    my @e = Genome::Model::Event->load(build_id => $self->build_id);

    # set status
    $self->_verify_build_is_not_abandoned_and_set_status_to('Succeeded', 1)
        or return;

    # set event status
    for my $e ($self->the_events(event_status => ['Running','Scheduled'])) {
        $e->event_status('Abandoned');
    }

    # report - if this fails set status back to Running, then the workflow will fail it
    unless ( $self->generate_send_and_save_report( $self->report_generator_class_for_success ) ) {
        $self->_verify_build_is_not_abandoned_and_set_status_to('Running');
        return;
    }
    
    # Launch new builds for any convergence models containing this model.
    # To prevent infinite loops, don't do this for convergence builds.
    # FIXME convert this to use the commit callback and model links with a custom notify that doesn't require succeeded builds
    if($self->type_name !~ /convergence/) {
        for my $model_group ($self->model->model_groups) {
            eval {
                $model_group->schedule_convergence_rebuild;
            };
            if($@) {
                $self->error_message('Could not schedule convergence build for model group ' . $model_group->id . '.  Continuing anyway.');
            }
        }
    }

    my $commit_callback;
    $commit_callback = sub {
        $self->the_master_event->cancel_change_subscription('commit', $commit_callback); #only fire once
        $self->status_message('Firing build success commit callback.');
        my $result = eval {
            $self->processing_profile->_build_success_callback($self);
        };
        if($@) {
            $self->error_message('Error executing success callback: ' . $@);
            return;
        }
        unless($result) {
            $self->error_message('Success callback failed.');
            return;
        }

        return UR::Context->commit; #a separate commit is necessary for any changes in the callback
    };

    #The build itself has no __changes__ and UR::Context->commit() will not trigger the subscription if on that object, so
    #use the master build event which has just been updated to 'Succeeded' with the current time.
    $self->the_master_event->create_subscription(
        method => 'commit',
        callback => $commit_callback,
    );

    # reallocate - always returns true (legacy behavior)
    $self->reallocate; 

    # FIXME Don't know if this should go here, but then we would have to call success and abandon through the model
    my $last_complete_build = $self->model->resolve_last_complete_build;
    unless ( $last_complete_build ) {
        $self->error_message("Tried to resolve last complete build for model (".$self->model_id."), but no build was returned.");
        # FIXME soon - return here
        #return;
    }
    unless ( $last_complete_build->id eq $self->id ) {
        $self->error_message("Tried to resolve last complete build for model (".$self->model_id."), which should return this build (".$self->id."), but returned another build (".$last_complete_build->id.").");
        # FIXME soon - return here
        #return;
    }

    return 1;
}

sub _verify_build_is_not_abandoned_and_set_status_to {
    my ($self, $status, $set_date_completed) = @_;

    my $build_event = $self->build_event;
    # Do we have a master event?
    unless ( $build_event ) {
        $self->error_message(
            'Cannot set build ('.$self->id.") status to '$status' because it does not have a master event."
        );
        return;
    }

    # Is it abandoned?
    if ( $build_event->event_status eq 'Abandoned' ) {
        $self->error_message(
            'Cannot set build ('.$self->id.") status to '$status' because the master event has been abandoned."
        );
        return;
    }

    # Set status and date completed
    $build_event->event_status($status);
    $build_event->date_completed( UR::Time->now ) if $set_date_completed;

    return $build_event;
}


sub abandon {
    my $self = shift;

    my $status = $self->status;
    if ($status && $status eq 'Abandoned') {
        return 1;
    }

    if ($status && ($status eq 'Running' || $status eq 'Scheduled')) {
        $self->stop;
    }

    # Abandon events
    $self->_abandon_events
        or return;

    # Reallocate - always returns true (legacy behavior)
    $self->reallocate;

    # FIXME Don't know if this should go here, but then we would have to call success and abandon through the model
    my $last_complete_build = $self->model->resolve_last_complete_build;
    if ( $last_complete_build and $last_complete_build->id eq $self->id ) {
        $self->error_message("Tried to resolve last complete build for model (".$self->model_id."), which should not return this build (".$self->id."), but did.");
        # FIXME soon - return here
        # return;
    }

    return 1;
}

sub _abandon_events { # does not realloc
    my $self = shift;

    my @events = sort { $b->id <=> $a->id } $self->events;
    for my $event ( @events ) {
        unless ( $event->abandon ) {
            $self->error_message(
                sprintf(
                    'Failed to abandon build (%s) because could not abandon event (%s).',
                    $self->id,
                    $event->id,
                )
            );
            return;
        }
    }

    return 1;
}

sub reports {
    my $self = shift;
    my $report_dir = $self->resolve_reports_directory;
    return unless -d $report_dir;
    return Genome::Report->create_reports_from_parent_directory($report_dir);
}

sub get_report {
    my ($self, $report_name) = @_;

    unless ( $report_name ) { # die?
        $self->error_message("No report name given to get report");
        return;
    }

    my $report_dir = $self->reports_directory.'/'.
    Genome::Report->name_to_subdirectory($report_name);
    return unless -d $report_dir;

    return Genome::Report->create_report_from_directory($report_dir); 
}

sub available_reports {
    my $self = shift;
    my $report_dir = $self->resolve_reports_directory;
    return unless -d $report_dir;
    return Genome::Report->create_reports_from_parent_directory($report_dir);
}

sub generate_send_and_save_report {
    my ($self, $generator_class, $additional_params) = @_;
    
    $additional_params ||= {};
    my $generator = $generator_class->create(
        build_id => $self->id,
        %$additional_params,
    );
    unless ( $generator ) {
        $self->error_message(
            sprintf(
                "Can't create report generator (%s) for build (%s)",
                $generator_class,
                $self->id
            )
        );
        return;
    }

    my $report = $generator->generate_report;
    unless ( $report ) {
        $self->error_message(
            sprintf("Can't generate report (%s) for build (%s)", $generator->name, $self->id)
        );
        return;
    }
    
    my $to = $self->_get_to_addressees_for_report_generator_class($generator_class)
        or return;
    
    my $email_confirmation = Genome::Report::Email->send_report(
        report => $report,
        to => $to,
        from => 'apipe@genome.wustl.edu',
        replyto => 'noreply@genome.wustl.edu',
        # maybe not the best/correct place for this information but....
        xsl_files => [ $generator->get_xsl_file_for_html ],
    );
    unless ( $email_confirmation ) {
        $self->error_message('Couldn\'t email build report ('.lc($report->name).')');
        return;
    }

    $self->add_report($report)
        or return;

    return $report;
}

sub _get_to_addressees_for_report_generator_class {
    my ($self, $generator_class) = @_;

    confess "No report generator class given to get 'to' addressees" unless $generator_class;

    my $user = $self->build_event->user_name;
    # Send reports to user unless it's apipe
    unless ( $user eq 'apipe' ) {
        return $self->build_event->user_name.'@genome.wustl.edu';
    }

    # Send failed reports to bulk
    return 'apipe-bulk@genome.wustl.edu' if $generator_class eq 'Genome::Model::Report::BuildFailed';

    # Send others to run
    return 'apipe-run@genome.wustl.edu';
}

sub report_generator_class_for_success { # in subclass replace w/ summary or the like?
    return 'Genome::Model::Report::BuildSucceeded';
}

#< SUBCLASSING >#
#
# This is called by the infrastructure to appropriately classify abstract processing profiles
# according to their type name because of the "sub_classification_method_name" setting
# in the class definiton...
sub _resolve_subclass_name {
    my $class = shift;

    my $type_name;
	if ( ref($_[0]) and $_[0]->isa(__PACKAGE__) ) {
		$type_name = $_[0]->model->type_name;
	}
    else {
        my ($bx,@extra) = $class->define_boolexpr(@_);
        my %params = ($bx->params_list, @extra);
        my $model_id = $params{model_id};
        my $model = Genome::Model->get($model_id);
        unless ($model) {
            return undef;
        }
        $type_name = $model->type_name;
    }

    unless ( $type_name ) {
        my $rule = $class->define_boolexpr(@_);
        $type_name = $rule->specified_value_for_property_name('type_name');
    }

    if (defined $type_name ) {
        my $subclass_name = $class->_resolve_subclass_name_for_type_name($type_name);
        my $sub_classification_method_name = $class->get_class_object->sub_classification_method_name;
        if ( $sub_classification_method_name ) {
            if ( $subclass_name->can($sub_classification_method_name)
                 eq $class->can($sub_classification_method_name) ) {
                return $subclass_name;
            } else {
                return $subclass_name->$sub_classification_method_name(@_);
            }
        } else {
            return $subclass_name;
        }
    } else {
        return undef;
    }
}

sub _resolve_subclass_name_for_type_name {
    my ($class,$type_name) = @_;
    my @type_parts = split(' ',$type_name);

    my @sub_parts = map { ucfirst } @type_parts;
    my $subclass = join('',@sub_parts);

    my $class_name = join('::', 'Genome::Model::Build' , $subclass);
    return $class_name;

}

sub _resolve_type_name_for_class {
    my $class = shift;

    my ($subclass) = $class =~ /^Genome::Model::Build::([\w\d]+)$/;
    return unless $subclass;

    return lc join(" ", ($subclass =~ /[a-z\d]+|[A-Z\d](?:[A-Z\d]+|[a-z]*)(?=$|[A-Z\d])/gx));

    my @words = $subclass =~ /[a-z\d]+|[A-Z\d](?:[A-Z\d]+|[a-z]*)(?=$|[A-Z\d])/gx;
    return lc(join(" ", @words));
}

sub get_all_objects {
    my $self = shift;

    my $sorter = sub { # not sure why we sort, but I put it in a anon sub for convenience
        return unless @_;
        #if ( $_[0]->id =~ /^\-/) {
            return sort {$b->id cmp $a->id} @_;
            #} 
            #else {
            #return sort {$a->id cmp $b->id} @_;
            #}
    };

    return map { $sorter->( $self->$_ ) } (qw/ events inputs metrics from_build_links to_build_links variants/);
}

sub yaml_string {
    my $self = shift;
    my $string = YAML::Dump($self);
    for my $object ($self->get_all_objects) {
        $string .= YAML::Dump($object);
    }
    return $string;
}

sub add_to_build{
    my $self = shift;
    my (%params) = @_;
    my $build = delete $params{to_build};
    my $role = delete $params{role};
    $role||='member';
   
    $self->error_message("no to_build provided!") and die unless $build;
    my $from_id = $self->id;
    my $to_id = $build->id;
    unless( $to_id and $from_id){
        $self->error_message ( "no value for this build(from_build) id: <$from_id> or to_build id: <$to_id>");
        die;
    }
    my $reverse_bridge = Genome::Model::Build::Link->get(from_build_id => $to_id, to_build_id => $from_id);
    if ($reverse_bridge){
        my $string =  "A build link already exists for these two builds, and in the opposite direction than you specified:\n";
        $string .= "to_build: ".$reverse_bridge->to_build." (this build)\n";
        $string .= "from_build: ".$reverse_bridge->from_build." (the build you are trying to set as a 'to' build for this one)\n";
        $string .= "role: ".$reverse_bridge->role;
        $self->error_message($string);
        die;
    }
    my $bridge = Genome::Model::Build::Link->get(from_build_id => $from_id, to_build_id => $to_id);
    if ($bridge){
        my $string =  "A build link already exists for these two builds:\n";
        $string .= "to_build: ".$bridge->to_build." (the build you are trying to set as a 'to' build for this one)\n";
        $string .= "from_build: ".$bridge->from_build." (this build)\n";
        $string .= "role: ".$bridge->role;
        $self->error_message($string);
        die;
    }
    $bridge = Genome::Model::Build::Link->create(from_build_id => $from_id, to_build_id => $to_id, role => $role);
    return $bridge;
}

sub add_from_build { # rename "add an underlying build" or something...
    my $self = shift;
    my (%params) = @_;
    my $build = delete $params{from_build};
    my $role = delete $params{role};
    $role||='member';
   
    $self->error_message("no from_build provided!") and die unless $build;
    my $to_id = $self->id;
    my $from_id = $build->id;
    unless( $to_id and $from_id){
        $self->error_message ( "no value for this build(to_build) id: <$to_id> or from_build id: <$from_id>");
        die;
    }
    my $reverse_bridge = Genome::Model::Build::Link->get(from_build_id => $to_id, to_build_id => $from_id);
    if ($reverse_bridge){
        my $string =  "A build link already exists for these two builds, and in the opposite direction than you specified:\n";
        $string .= "to_build: ".$reverse_bridge->to_build." (the build you are trying to set as a 'from' build for this one)\n";
        $string .= "from_build: ".$reverse_bridge->from_build." (this build)\n";
        $string .= "role: ".$reverse_bridge->role;
        $self->error_message($string);
        die;
    }
    my $bridge = Genome::Model::Build::Link->get(from_build_id => $from_id, to_build_id => $to_id);
    if ($bridge){
        my $string =  "A build link already exists for these two builds:\n";
        $string .= "to_build: ".$bridge->to_build." (this build)\n";
        $string .= "from_build: ".$bridge->from_build." (the build you are trying to set as a 'from' build for this one)\n";
        $string .= "role: ".$bridge->role;
        $self->error_message($string);
        die;
    }
    $bridge = Genome::Model::Build::Link->create(from_build_id => $from_id, to_build_id => $to_id, role => $role);
    return $bridge;
}

sub delete {
    my $self = shift;
    my %params = @_;
    my $keep_build_directory = $params{keep_build_directory};

    # Abandon events
    $self->status_message("Abandoning events associated with build");
    unless ($self->_abandon_events) {
        $self->error_message(
            "Unable to delete build (".$self->id.") because the events could not be abandoned"
        );
        confess $self->error_message;
    }
    
    # Delete all associated objects
    $self->status_message("Deleting other objects associated with build");
    my @objects = $self->get_all_objects;
    for my $object (@objects) {
        $object->delete;
    }

    # Re-point instrument data assigned first on this build to the next build.
    $self->status_message("Pointing instrument data first assigned to this build to a subsequent build, if possible");
    my ($next_build,@subsequent_builds) = Genome::Model::Build->get(
        model_id => $self->model_id,
        id => {
            operator => '>',
            value => $self->build_id,
        },  
    );
    my $next_build_id = ($next_build ? $next_build->id : undef);
    my @idas_fix = Genome::Model::InstrumentDataAssignment->get(
        model_id => $self->model_id,
        first_build_id => $self->build_id
    );
    for my $idas (@idas_fix) {
        $idas->first_build_id($next_build_id);
    }

    # Remove build directory unless told not to
    # TODO If no-commit is on, the build directory should not be removed
    if ($self->data_directory && -e $self->data_directory && !$keep_build_directory) {
        $self->status_message("Removing build data directory at " . $self->data_directory);
        my $rv = Genome::Sys->remove_directory_tree($self->data_directory);
        confess "Failed to remove build directory at " . $self->data_directory unless defined $rv and $rv;
    }
    else {
        $self->status_message("Not removing build data directory at " . $self->data_directory);
    }

    # Deallocate build directory if it was removed and an allocation is found
    my $disk_allocation = $self->disk_allocation;
    if ($disk_allocation && !$keep_build_directory) {
        $self->status_message("Deallocating build directory");
        unless ($disk_allocation->deallocate) {
             $self->warning_message('Failed to deallocate disk space.');
        }
    }
    else {
        $self->status_message("Not deallocating build directory since it was not removed or no allocation was found");
    }
    
    # FIXME Don't know if this should go here, but then we would have to call success and abandon through the model
    #  This works b/c the events are deleted prior to this call, so the model doesn't think this is a completed
    #  build
    my $last_complete_build = $self->model->resolve_last_complete_build;
    if ( $last_complete_build and $last_complete_build->id eq $self->id ) {
        $self->error_message("Tried to resolve last complete build for model (".$self->model_id."), which should not return this build (".$self->id."), but did.");
        # FIXME soon - return here
        # return;
    }

    return $self->SUPER::delete;
}

sub set_metric {
    my $self = shift;
    my $metric_name  = shift;
    my $metric_value = shift;

    my $metric = Genome::Model::Metric->get(build_id=>$self->id, name=>$metric_name);
    my $new_metric;
    if ($metric) {
        #delete an existing one and create the new one
        $metric->delete;
        $new_metric = Genome::Model::Metric->create(build_id=>$self->id, name=>$metric_name, value=>$metric_value);
    } else {
        $new_metric = Genome::Model::Metric->create(build_id=>$self->id, name=>$metric_name, value=>$metric_value);
    }
    
    return $new_metric->value;
}

sub get_metric {
    my $self = shift;
    my $metric_name = shift;

    my $metric = Genome::Model::Metric->get(build_id=>$self->id, name=>$metric_name);
    if ($metric) {
        return $metric->value;
    }
}

# Returns a list of files contained in the build's data directory
sub files_in_data_directory { 
    my $self = shift;
    my @files;
    find({
        wanted => sub {
            my $file = $File::Find::name;
            push @files, $file;
        },
        follow => 1, },
        $self->data_directory,
    );
    return \@files;
}

# Given a full path to a file, return a path relative to the build directory
sub full_path_to_relative {
    my ($self, $path) = @_;
    my $rel_path = $path;
    my $dir = $self->data_directory;
    $dir .= '/' unless substr($dir, -1, 1) eq '/';
    $rel_path =~ s/$dir//;
    $rel_path .= '/' if -d $path and substr($rel_path, -1, 1) ne '/';
    return $rel_path;
}

# Returns a list of files that should be ignored by the diffing done by compare_output
# Files should be relative to the data directory of the build and can contain regex.
# Override in subclasses!
sub files_ignored_by_diff {
    return ();
}

# Returns a list of directories that should be ignored by the diffing done by compare_output
# Directories should be relative to the data directory of the build and can contain regex.
# Override in subclasses!
sub dirs_ignored_by_diff {
    return ();
}

# A list of regexes that, when applied to file paths that are relative to the build's data
# directory, return only one result. This is useful for files that don't have consistent
# names between builds (for example, if they have the build_id embedded in them. Override
# in subclasses!
sub regex_files_for_diff {
    return ();
}

# A list of metrics that the differ should ignore. Some model/build types store information
# as metrics that need to be diffed. Override this in subclasses.
sub metrics_ignored_by_diff {
    return ();
}

# A list of file suffixes that require special treatment to diff. This should include those
# files that have timestamps or other changing fields in them that an md5sum can't handle.
# Each suffix should have a method called diff_<SUFFIX> that'll contain the logic.
sub special_suffixes {
    return qw(
        gz
    );
}

# Gzipped files contain the timestamp and name of the original file, so this prints
# the uncompressed file to STDOUT and pipes it to md5sum.
sub diff_gz {
    my ($self, $first_file, $second_file) = @_;
    my $first_md5 = `gzip -dc $first_file | md5sum`;
    my $second_md5 = `gzip -dc $second_file | md5sum`;
    return 1 if $first_md5 eq $second_md5;
    return 0;
}

# This method takes another build id and compares that build against this one. It gets
# a list of all the files in both builds and attempts to find pairs of corresponding
# files. The files/dirs listed in the files_ignored_by_diff and dirs_ignored_by_diff
# are ignored entirely, while files listed by regex_files_for_diff are retrieved
# using regex instead of a simple string eq comparison. 
sub compare_output {
    my ($self, $other_build_id) = @_;
    my $build_id = $self->build_id;
    confess "Require build ID argument!" unless defined $other_build_id;
    my $other_build = Genome::Model::Build->get($other_build_id);
    confess "Could not get build $other_build_id!" unless $other_build;

    unless ($self->model_id eq $other_build->model_id) {
        confess "Builds $build_id and $other_build_id are not from the same model!";
    }
    unless ($self->class eq $other_build->class) {
        confess "Builds $build_id and $other_build_id are not the same type!";
    }

    # Create hashes for each build, keys are paths relative to build directory and 
    # values are full file paths
    my (%file_paths, %other_file_paths);
    require Cwd;
    for my $file (@{$self->files_in_data_directory}) {
        $file_paths{$self->full_path_to_relative($file)} = Cwd::abs_path($file);
    }
    for my $other_file (@{$other_build->files_in_data_directory}) {
        $other_file_paths{$other_build->full_path_to_relative($other_file)} = Cwd::abs_path($other_file);
    }

    # Now cycle through files in this build's data directory and compare with 
    # corresponding files in other build's dir
    my %diffs;
    FILE: for my $rel_path (sort keys %file_paths) {
        my $abs_path = delete $file_paths{$rel_path};
        my $dir = $self->full_path_to_relative(dirname($abs_path));
       
        next FILE if -d $abs_path;
        next FILE if grep { $dir =~ /$_/ } $self->dirs_ignored_by_diff;
        next FILE if grep { $rel_path =~ /$_/ } $self->files_ignored_by_diff;

        # Gotta check if this file matches any of the supplied regex patterns. 
        # If so, find the one (and only one) file from the other build that 
        # matches the same pattern
        my ($other_rel_path, $other_abs_path);
        REGEX: for my $regex ($self->regex_files_for_diff) {
            next REGEX unless $rel_path =~ /$regex/;

            my @other_keys = grep { $_ =~ /$regex/ } sort keys %other_file_paths;
            if (@other_keys > 1) {
                $diffs{$rel_path} = "multiple files from $other_build_id matched file name pattern $regex\n" . join("\n", @other_keys);
                map { delete $other_file_paths{$_} } @other_keys;
                next FILE;
            }
            elsif (@other_keys < 1) {
                $diffs{$rel_path} = "no files from $other_build_id matched file name pattern $regex";
                next FILE;
            }
            else {
                $other_rel_path = shift @other_keys;
                $other_abs_path = delete $other_file_paths{$other_rel_path};
            }
        }

        # If file name doesn't match any regex, assume relative paths are the same
        unless (defined $other_rel_path and defined $other_abs_path) {
            $other_rel_path = $rel_path;
            $other_abs_path = delete $other_file_paths{$other_rel_path};
            unless (defined $other_abs_path) {
                $diffs{$rel_path} = "no file $rel_path from build $other_build_id";
                next FILE;
            }
        }
      
        # Check if the files end with a suffix that requires special handling. If not,
        # just do an md5sum on the files and compare
        my $diff_result = 0;
        my (undef, undef, $suffix) = fileparse($abs_path, $self->special_suffixes);
        my (undef, undef, $other_suffix) = fileparse($other_abs_path, $self->special_suffixes);
        if ($suffix ne '' and $other_suffix ne '' and $suffix eq $other_suffix) {
            my $method = "diff_$suffix";
            $diff_result = $self->$method($abs_path, $other_abs_path);
        }
        else {
            my $file_md5 = Genome::Sys->md5sum($abs_path);
            my $other_md5 = Genome::Sys->md5sum($other_abs_path);
            $diff_result = ($file_md5 eq $other_md5);
        }

        unless ($diff_result) {
            $diffs{$rel_path} = "files $abs_path and $other_abs_path are not the same!";
        }
    }

    # Make sure the other build doesn't have any extra files
    for my $rel_path (sort keys %other_file_paths) {
        my $abs_path = delete $other_file_paths{$rel_path};
        my $dir = $self->full_path_to_relative(dirname($abs_path));
        next if -d $abs_path;
        next if grep { $dir =~ /$_/ } $self->dirs_ignored_by_diff;
        next if grep { $rel_path =~ /$_/ } $self->files_ignored_by_diff;
        $diffs{$rel_path} = "no file $rel_path from build $build_id";
    }

    # Now compare metrics of both builds
    my %metrics;
    map { $metrics{$_->name} = $_ } $self->metrics;
    my %other_metrics;
    map { $other_metrics{$_->name} = $_ } $other_build->metrics;

    METRIC: for my $metric_name (sort keys %metrics) {
        my $metric = $metrics{$metric_name};

        if ( grep { $metric_name =~ /$_/ } $self->metrics_ignored_by_diff ) {
            delete $other_metrics{$metric_name} if exists $other_metrics{$metric_name};
            next METRIC;
        }

        my $other_metric = delete $other_metrics{$metric_name};
        unless ($other_metric) {
            $diffs{$metric_name} = "no build metric with name $metric_name found for build $other_build_id";
            next METRIC;
        }

        my $metric_value = $metric->value;
        my $other_metric_value = $other_metric->value;
        unless ($metric_value eq $other_metric_value) {
            $diffs{$metric_name} = "metric $metric_name has value $metric_value for build $build_id and value " .
            "$other_metric_value for build $other_build_id";
            next METRIC;
        }
    }

    # Catch any extra metrics that the other build has
    for my $other_metric_name (sort keys %other_metrics) {
        $diffs{$other_metric_name} = "no build metric with name $other_metric_name found for build $build_id";
    }

    return %diffs;
}

1;
