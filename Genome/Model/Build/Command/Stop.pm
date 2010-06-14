package Genome::Model::Build::Command::Stop;

use strict;
use warnings;

use Genome;
use Genome::Model::Command::Services::Build::Scan;


class Genome::Model::Build::Command::Stop {
    is => 'Genome::Model::Build::Command::Base',
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

    # Get build
    my $build = $self->_resolve_build
        or return;

    my $job_id = $build->the_master_event->lsf_job_id;

    if ($build->run_by ne $ENV{USER}) {
        $self->error_message("Can't stop a build originally started by: " . $build->run_by);
        return 0;
    }

    unless (my $job = $self->get_job($job_id)) {
        if ($job->{Status} ne 'EXIT' && $job->{Status} ne 'DONE') {
            $self->error_message("Build not running");
            return 0;
        }
    }

    Genome::Utility::FileSystem->shellcmd(
        cmd => "bkill $job_id"
    );

    my $i = 0;
    my $job;
    do {
        $self->status_message("Waiting for job to stop") if ($i % 10 == 0);
        $i++;
        sleep 1;
        $job = $self->get_job($job_id);

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

sub get_job {
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

1;

#$HeadURL$
#$Id$
