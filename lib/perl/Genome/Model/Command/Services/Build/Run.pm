package Genome::Model::Command::Services::Build::Run;

use strict;
use warnings;

use Carp;
use Genome;
use Workflow;

use Regexp::Common;

class Genome::Model::Command::Services::Build::Run{
    is => 'Genome::Model::Command',
    has => [
            build_id =>{
                         is => 'Number',
                         doc => 'The id of the build in which to update status',
                         is_optional => 1,
                     },
            build   => {
                        is => 'Genome::Model::Build',
                        id_by => 'build_id',
                        is_optional => 1,
                    },
            restart => {
                is => 'Boolean',
                is_optional => 1,
                doc => 'Restart a new Workflow Instance. Overrides the default behavior of resuming an existing workflow.' 
            },
            inline => {
                is => 'Boolean',
                is_optional => 1,
                doc => 'Run the entire build without bsubbing to other hosts (disables resource requirements and logs)'
            }
    ],
    doc => 'launch all jobs for a build (new)'
};

sub sub_command_sort_position { 2 }

sub help_detail {
    return <<EOS 
EOS
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    unless (defined $self->build_id ) {
        my $model = $self->model;
        unless ($model) {
            $self->delete;
            return;
        }
        my $build_id = $model->current_running_build_id;
        unless ($build_id) {
            $self->error_message('Failed to get build_id for model '. $model->id);
        }
        $self->build_id($build_id);
    }
    unless ( $self->_verify_build ) {
        $self->delete;
        return;
    }
    return $self;
}

sub _verify_build {
    my $self = shift;

    unless ( defined $self->build_id ) {
        $self->error_message("No build id given");
        return;
    }

    unless ( $self->build_id =~ /^$RE{num}{int}$/ ) {
        $self->error_message( sprintf('Build id given (%s) is not an integer', $self->build_id) );
        return;
    }

    unless ( $self->build ) {
        $self->error_message( sprintf('Can\'t get build for id (%s) ', $self->build_id) );
        return;
    }

    return 1;
}

sub execute {
    my $self = shift;

    my $build = $self->build;

    my $xmlfile = $self->build->data_directory . '/build.xml';

    if (!-e $xmlfile) {
        $self->error_message("Can't find xml file for build (" . $self->build_id . "): " . $xmlfile);
        return 0;
    }

    require Workflow::Simple;

    my $loc_file = $self->build->data_directory . '/server_location.txt';
    if (-e $loc_file) {
        $self->error_message("Server location file in build data directory exists, if you are sure it is not currently running remove it and run again: $loc_file");
        return 0;
    } 

    $Workflow::Simple::server_location_file = $loc_file;

    my $w = $build->newest_workflow_instance;
    if ($w && !$self->restart) {
        if ($w->is_done) {
            $self->error_message("Workflow Instance is complete, if you are sure you need to restart use the --restart option");
            return 0;
        }
    }

    eval {
        $build->initialize;
    };
    if ($@) {
        return $self->_post_build_failure($@);
    }

    UR::Context->commit;
    $w = $build->newest_workflow_instance;

    my $success;
    if ($self->inline) {
        if ($w && !$self->restart) {

            $self->set_not_running($w);
            UR::Context->commit;

            $success = Workflow::Simple::resume($w->id);
        } 
        else {
            my %inputs = $build->processing_profile->_map_workflow_inputs($build);
            $success = Workflow::Simple::run_workflow(
                $xmlfile,
                %inputs
            );
        }

    } else {
        if (Genome::DataSource::GMSchema->has_default_handle) {
            $self->status_message("Disconnecting GMSchema default handle.");
            Genome::DataSource::GMSchema->disconnect_default_dbh();
        }

        local $ENV{WF_TRACE_UR} = 1;
        local $ENV{WF_TRACE_HUB} = 1;
        if ($w && !$self->restart) {

            $self->set_not_running($w);
            UR::Context->commit;
            if (Workflow::DataSource::InstanceSchema->has_default_handle) {
                $self->status_message("Disconnecting InstanceSchema default handle.");
                Workflow::DataSource::InstanceSchema->disconnect_default_dbh();
            }

            $success = Workflow::Simple::resume_lsf($w->id);
        } 
        else {
            my %inputs = $build->processing_profile->_map_workflow_inputs($build);
            if (Workflow::DataSource::InstanceSchema->has_default_handle) {
                $self->status_message("Disconnecting InstanceSchema default handle.");
                Workflow::DataSource::InstanceSchema->disconnect_default_dbh();
            }

            $success = Workflow::Simple::run_workflow_lsf(
                $xmlfile,
                %inputs
            );
        }
    }

    # Failed a stage/step - send report
    unless ( $success ) {
        unless ( @Workflow::Simple::ERROR ) {
            return $self->_post_build_failure("Workflow failed, but no errors given");
        }
        my @errors = Genome::Model::Build::Error->create_from_workflow_errors(
            @Workflow::Simple::ERROR 
        );
        
        unless ( @errors ) {
            print STDERR "Can't convert workflow errors to build errors\n";
            print STDERR Data::Dumper->new([\@Workflow::Simple::ERROR],['ERROR'])->Dump;
            return $self->_post_build_failure("Can't convert workflow errors to build errors");
        }
        unless ( $build->fail(@errors) ) {
            return $self->_failed_build_fail(@errors);
        }
        return 1;
    }

    # shall we clean up old builds?
    if ( defined $build->model->keep_n_most_recent_builds ) {
        my $handle_build_evisceration = sub {
            $self->_eviscerate_old_builds_for_this_model;
        };
        $self->create_subscription(method => 'commit', callback => $handle_build_evisceration);
    }

    # Success - realloc and send report
    unless ( $build->success ) {
        my $msg = sprintf(
            'Failed to set build to success: %s',
            $build->error_text || 'no error given',
        );
        return $self->_post_build_failure($msg);
    }

    UR::Context->commit();

    require UR::Object::View::Default::Xsl;

    my $cachetrigger = Genome::Config->base_web_uri;
    $cachetrigger =~ s/view$/cachetrigger/;

    my $url = $cachetrigger . '/' . UR::Object::View::Default::Xsl::type_to_url     (ref($build)) . '/status.html?id=' . $build->id;

    system("curl -k $url >/dev/null 2>/dev/null &");

    return 1;
}

sub set_not_running {
 my ($self, $instance) = @_;

 $instance->is_running(0);
 if ($instance->can('child_instances')) {
     for ($instance->child_instances) {
         $self->set_not_running($_);
     }
 }
}


sub _post_build_failure { 
    my ($self, $msg) = @_;
    
    $self->error_message($msg);

    my $build_event = $self->build->build_event;
    my $error = Genome::Model::Build::Error->create(
        build_event_id => $build_event->id,
        stage_event_id => $build_event->id,
        stage => 'all stages',
        step_event_id => $build_event->id,
        step => 'main',
        error => $msg,
    );
    
    unless ( $self->build->fail($error) ) {
        return $self->_failed_build_fail($error);
    }

    return 1;
}

sub _failed_build_fail {
    my ($self, @errors) = @_;

    my $msg = sprintf(
        "Failed to fail build because: %s\nOriginal errors:\n%s",
        ( $self->build->error_text || 'No error given' ),
        join("\n", map { $_->error } @errors),
    );

    $self->error_message($msg);

    return 1;
}

sub _eviscerate_old_builds_for_this_model {
    # NOT TESTED!
    my $self = shift;
    my $subscription = shift;
    my $model = $self->build->model;
    my $this_build = $self->build;

    # a couple guards here, to make sure we don't run by accident
    # don't run on failed builds or models that ask to be eviscerated!
    return if ($self->event_status ne 'Succeeded');

    unless (defined $model->keep_n_most_recent_builds) {
        return;
    }

    my $recent_keep_count = $model->keep_n_most_recent_builds;

    # The calling build will not have been marked as succeeded yet, so allow an "or" here to catch our own build
    my @builds = sort {$a->build_id <=> $b->build_id}
    grep {$_->can('eviscerate')}
    grep {$_->status eq "Succeeded" || $_->id == $self->build->id}
    $model->builds;

    my @builds_to_eviscerate = splice @builds, 0, scalar @builds - $recent_keep_count;

    for my $doomed_build (@builds_to_eviscerate) {
        next if (!$doomed_build->can('eviscerate'));
        my $resource_lock_name = $doomed_build->accumulated_alignments_directory . '.eviscerate';
        my $lock = Genome::Sys->lock_resource(resource_lock => $resource_lock_name, max_try => 2);
        print Dumper($lock);
        unless ($lock) {
            $self->status_message("This build is locked by another eviscerate process");
            $lock = $self->lock_resource(resource_lock => $resource_lock_name);
            unless ($lock) {
                $self->error_message("Failed to get a build lock to eviscerate!  Skipping this build.");
                next;
            }
        }

        $doomed_build->eviscerate;

        Genome::Sys->unlock_resource(resource_lock=>$lock);
    }
}

1;

#$HeadURL$
#$Id$
