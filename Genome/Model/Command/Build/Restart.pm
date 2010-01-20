package Genome::Model::Command::Build::Restart;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::Restart {
    is => 'Genome::Model::Command::Build::Base',
    has => [
        lsf_queue => {
            default_value => 'apipe',
            is_constant => 1,
        },
        restart => {
            is => 'Boolean',
            is_optional => 1,
            doc => 'Restart with a new workflow, overrides the default of resuming an old workflow'
        }
    ]
};

sub sub_command_sort_position { 5 }

sub help_detail {
    "Abandon a build and it's events";
}

sub execute {
    my $self = shift;

    # Get build
    my $build = $self->_resolve_build
        or return;

    if ($build->run_by ne $ENV{USER}) {
        $self->error_message("Can't restart a build originally started by: " . $build->run_by);
        return 0;
    }

    my $xmlfile = $build->data_directory . '/build.xml';
    if (!-e $xmlfile) {
        $self->error_message("Can't find xml file for build (" . $build->id . "): " . $xmlfile);
        return 0;
    }

    my $loc_file = $build->data_directory . '/server_location.txt';
    if (-e $loc_file) {
        $self->error_message("Server location file in build data directory exists, if you are sure it is not currently running remove it and run again: $loc_file");
        return 0;
    }

    my $w = $build->newest_workflow_instance;
    if ($w && !$self->restart) {
        if ($w->is_done) {
            $self->error_message("Workflow Instance is complete, if you are sure you need to restart use the --restart option");
            return 0;
        }
    }

    my $build_event = $build->build_event;
    my $lsf_command = sprintf(
        'bsub -N -H -q %s -m blades %s -g /build/%s -u %s@genome.wustl.edu -o %s -e %s genome model services build run%s --model-id %s --build-id %s',
        $self->lsf_queue,
        "-R 'select[type==LINUX86]'",
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
    UR::Context->create_subscription(
        method => 'commit',
        callback => sub{
            `bresume $job_id`;
        },
    );

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

1;

#$HeadURL$
#$Id$
