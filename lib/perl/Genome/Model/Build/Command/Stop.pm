package Genome::Model::Build::Command::Stop;

use strict;
use warnings;

use Genome;

use Genome::Model::Command::Services::Build::Scan;

class Genome::Model::Build::Command::Stop {
    is => 'Genome::Model::Build::Command',
    has => [
#        restart => {
#            is => 'Boolean',
#            is_optional => 1,
#            doc => 'Kill, then restart when it is fully shut down.'
#        }
    ]
};

sub sub_command_sort_position { 5 }

sub help_brief {
    "Stop a build";
}

sub help_detail {
    return help_brief();
}

sub execute {
    my $self = shift;

    my @builds = $self->_builds_for_filter; # confesses
    for my $build ( @builds ) {
        $self->_stop_build($build); # intentionally not checking return value
    }

    return 1;
}

sub _stop_build {
    my ($self, $build) = @_;

    if ($build->run_by ne $ENV{USER}) {
        $self->error_message("Can't stop a build originally started by: " . $build->run_by);
        return 0;
    }

    my $job = $self->get_running_master_lsf_job_for_build($build); 
    if ( not defined $job ) {
        $self->error_message("Build not running");
        return 0;
    }

    Genome::Utility::FileSystem->shellcmd(
        cmd => 'bkill '.$job->{Job},
    );

    my $i = 0;
    do {
        $self->status_message("Waiting for job to stop") if ($i % 10 == 0);
        $i++;
        sleep 1;
        $job = $self->get_job( $job->{Job} );

        if ($i > 60) {
            $self->error_message("Build master job did not die after 60 seconds.");
            return 0;
        }
    } while ($job && ($job->{Status} ne 'EXIT' && $job->{Status} ne 'DONE'));

    $build = Genome::Model::Build->load($build->id);

    my $build_event = $build->build_event;
    my $error = Genome::Model::Build::Error->create(
        build_event_id => $build_event->id,
        stage_event_id => $build_event->id,
        stage => 'all stages',
        step_event_id => $build_event->id,
        step => 'main',
        error => 'Killed by user',
    );

    unless ( $build->fail($error) ) {
        $self->error_message('Failed to fail build');

        return;
    }

    $self->status_message(sprintf(
        "Build (ID: %s DIR: %s) killed.\n",
        $build->id,
        $build->data_directory,
    ));

    return 1;
}

1;

#$HeadURL$
#$Id$
