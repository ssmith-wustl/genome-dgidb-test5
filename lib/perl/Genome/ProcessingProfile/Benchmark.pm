package Genome::ProcessingProfile::Benchmark;

use strict;
use warnings;
use Genome;

class Genome::ProcessingProfile::Benchmark {
    is => 'Genome::ProcessingProfile',
    has => [
        XXXserver_dispatch => {
            is_constant => 1,
            is_class_wide => 1,
            value => 'inline',
            doc => 'lsf queue to submit the launcher or \'inline\''
        },
        XXXjob_dispatch => {
            is_constant => 1,
            is_class_wide => 1,
            value => 'inline',
            doc => 'lsf queue to submit jobs or \'inline\' to run them in the launcher'
        }
    ],
    has_param => [
        command => {
            doc => 'command to benchmark',
        },
        args => {
            is_optional => 1,
            doc => 'the arguments to use',
        }
    ],
    doc => "benchmark profile captures statistics after command execution"
};

sub _initialize_model {
    my ($self,$model) = @_;
    warn "defining new model " . $model->__display_name__ . " for profile " . $self->__display_name__ . "\n";
    return 1;
}

sub _initialize_build {
    my ($self,$build) = @_;
    warn "defining new build " . $build->__display_name__ . " for profile " . $self->__display_name__ . "\n";
    return 1;
}

sub _execute_build {
    my ($self,$build) = @_;
    warn "executing build logic for " . $self->__display_name__ . ':' .  $build->__display_name__ . "\n";

    # combine params with build inputs and produce output in the build's data directory

    $DB::single=1;

    my $cmd = $self->command;
    my $args = $self->args || '';

#    my @inputs = $build->inputs();

    my $dir = $build->data_directory;

    my $exit_code = system "$cmd $args >$dir/output 2>$dir/errors";
    $exit_code = $exit_code >> 8;
    if ($exit_code != 0) {
        $self->error_message("Failed to run $cmd with args $args!  Exit code: $exit_code.");
        return;
    }

    return 1;
}

sub _validate_build {
    my $self = shift;
    my $dir = $self->data_directory;
    
    my @errors;
    unless (-e "$dir/output") {
        my $e = $self->error_message("No output file $dir/output found!");
        push @errors, $e;
    }
    unless (-e "$dir/errors") {
        my $e = $self->error_message("No output file $dir/errors found!");
        push @errors, $e;
    }

    if (@errors) {
        return;
    }
    else {
        return 1;
    }
}

1;

