package Genome::Model::Command::Services::BuildQueuedModels;

use strict;
use warnings;

use Data::Dumper;

use Genome;


class Genome::Model::Command::Services::BuildQueuedModels {
    is  => 'Command',
    has => [
        max_builds => {
            is          => 'Number',
            is_optional => 1,
            len         => 5,
            default     => 200,
            doc         => 'Max # of builds to launch in one invocation',   
        },
        newest_first => {
            is          => 'Boolean',
            is_optional => 1,
            default     => 0,
            doc         => 'Process newest models first',
        },
        _builds_started => {
            is          => 'Number',
            is_output   => 1,
            default     => 0,
            doc         => 'Number of builds successfully launched',
        }
    ],
};

sub help_brief {
'Find models with the build_requested flag set and launch builds for them';
}

sub help_synopsis {
    return <<'EOS'
EOS
}

sub help_detail {
    return <<EOS
EOS
}

sub execute {
    $DB::single = $DB::stopper;
    my $self = shift;

    # lock
    my $lock_resource = '/gsc/var/lock/genome_model_command_services_build-queued-models/loader';
    my $lock = Genome::Sys->lock_resource(
        resource_lock => $lock_resource,
        max_try => 1
    ); 
    unless ($lock) {
        $self->error_message("Could not acquire lock, another instance must be running.");
        return;
    }

    my $model_sorter;
    if ($self->newest_first) {
        $model_sorter = sub { $b->id <=> $a->id };
    }
    else {
        $model_sorter = sub { $a->id <=> $b->id };
    }

    my @models = Genome::Model->get(
        build_requested => 1,
    );

    $DB::single = 1;
    my $builds_to_start = $self->max_builds;
    $builds_to_start = @models if @models < $builds_to_start;
    my $command = Genome::Model::Build::Command::Start->create(
        max_builds => $self->max_builds,
        models => \@models,
    );
    my $rv = $command->execute;
    my $err = $@;

    my @builds = $command->builds;
    unless (@builds == $builds_to_start){
        die $self->error_message("Failed to start expected number of builds. $builds_to_start expected, ".scalar @builds." built.\nErr:$@");
    }
    unless ($rv){
        $self->error_message("Built expected number of builds, but had some failures:\nErr:$@");
    }

    Genome::Sys->unlock_resource(resource_lock=>$lock);

    return 1;
}

1;
