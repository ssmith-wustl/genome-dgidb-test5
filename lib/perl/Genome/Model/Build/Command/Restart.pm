package Genome::Model::Build::Command::Restart;

use strict;
use warnings;

use Genome;

require Carp;
require Cwd;
use Data::Dumper 'Dumper';

class Genome::Model::Build::Command::Restart {
    is => 'Genome::Model::Build::Command',
    has => [
        lsf_queue => {
            default_value => 'workflow',
            is_optional => 1,
            doc => 'Queue to restart the master job in (events stay in their original queue)'
        },
        restart => {
            is => 'Boolean',
            is_optional => 1,
            default_value => 0,
            doc => 'Restart with a new workflow, overrides the default of resuming an old workflow'
        },
        software_revision => {
            is => 'Text',
            is_optional => 1,
            doc => 'The software revision directory to be used by the build(s). Defaults to the current used libs via used_libs_perl5lib_prefix in UR::Util.',
        }
    ],
};

sub sub_command_sort_position { 5 }

sub help_brief {
    "Restart a builds master job on a blade";
}

sub help_detail {
    return help_brief();
}

sub execute {
    my $self = shift;

    # Validte software revision
    if ( my $software_revision = $self->software_revision ) {
        $software_revision =~ s/:$//;
        $software_revision = Cwd::abs_path($software_revision);
        if ( not defined $software_revision or not -d $software_revision ) {
            $self->error_message("Cannot resolve software revision directory: ".$self->software_revision);
            return;
        }
        $self->software_revision($software_revision.':');
    } 
    else {
        $self->software_revision( UR::Util::used_libs_perl5lib_prefix() );
    }

    # Restart each build - this will commit individual updates
    my @builds = $self->_builds_for_filter; # confesses
    for my $build ( @builds ) {
        $self->_restart_build($build); # intentionally not checking return value
    }

    # Resume jobs on final commit
    UR::Context->create_subscription(
        method => 'commit',
        callback => sub{ $self->_resume_jobs_for_builds(@builds); },
    );

    return 1;
}

sub _restart_build {
    my ($self, $build) = @_;

    if ( not defined $build ) {
        Carp::confess('No build given to restart');
    }

    $self->status_message('Attempting to restart build: '.$build->id);

    if ($build->run_by ne $ENV{USER}) {
        $self->error_message("Can't restart a build originally started by: " . $build->run_by);
        return 0;
    }

    my $xmlfile = $build->data_directory . '/build.xml';
    if (!-e $xmlfile) {
        $self->error_message("Can't find xml file for build (" . $build->id . "): " . $xmlfile);
        return 0;
    }

    # Check if the build is running
    my $job = $self->get_running_master_lsf_job_for_build($build);
    if ( $job ) {
        $self->error_message("Build is currently running. Stop it first, then restart.");
        return 0;
    }

    # Since the job is not running, check if there is server location file and rm it
    my $loc_file = $build->data_directory . '/server_location.txt';
    if ( -e $loc_file ) {
        $self->status_message("Removing server location file for dead lsf job: $loc_file");
        unlink $loc_file;
    }

    my $w = $build->newest_workflow_instance;
    if ($w && !$self->restart) {
        if ($w->is_done) {
            $self->error_message("Workflow Instance is complete, if you are sure you need to restart use the --restart option");
            return 0;
        }
    }

    my $build_event = $build->build_event;
    if($build_event->event_status eq 'Abandoned') {
        $self->error_message("Can't restart a build that was abandoned.  Start a new build instead.");
        return 0;
    }

    $build->software_revision( $self->software_revision );

    $build_event->event_status('Scheduled');
    $build_event->date_completed(undef);

    for my $e ($build->the_events(event_status => ['Running','Failed'])) {
        $e->event_status('Scheduled');
    }

    #TODO, the -m argument (host group, should be determined from the value of $self->lsf_queue, not hardcoded
    my $lsf_command = sprintf(
        'bsub -N -H -q %s -g /build/%s -u %s@genome.wustl.edu -o %s -e %s annotate-log genome model services build run%s --model-id %s --build-id %s',
        $self->lsf_queue,
        $ENV{USER},
        $ENV{USER},
        $build_event->output_log_file,
        $build_event->error_log_file,
        $self->restart ? ' --restart' : '',
        $build->model_id,
        $build->id,
    );

    my $job_id = $self->_execute_bsub_command($lsf_command)
        or return;
    $build_event->lsf_job_id($job_id);

    # Commit chenages to this build
    my $commit_rv = UR::Context->commit;
    if ( not $commit_rv ) {
        Carp::confess('Cannot commit update to build: '.$build->id);
    }

    printf(
        "Build (ID: %s DIR: %s) launched to LSF.\nAn initialization email will be sent once the build begins running.\n",
        $build->id,
        $build->data_directory,
    );

    return 1;
}

sub _execute_bsub_command { # here to overload in testing
    my ($self, $cmd) = @_;

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
        return "$1";
    } 
    else {
        $self->error_message("Launched busb command, but unable to parse bsub output: $bsub_output");
        return;
    }
}   

sub _resume_jobs_for_builds {
    my ($self, @builds) = @_;

    for my $build ( @builds ) {
        my $job_id = $build->the_master_event->lsf_job_id;
        `bresume $job_id`;
    }

    return 1;
}

1;

#$HeadURL$
#$Id$
