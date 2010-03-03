package Genome::ProcessingProfile::ReferenceVariationSanger;

use strict;
use warnings;
use Genome;

class Genome::ProcessingProfile::ReferenceVariationSanger {
    is => 'Genome::ProcessingProfile',
    has_param => [
        command_name => {
            doc => 'gmt analysis auto-msa',
        },
        args => {
            is_optional => 1,
            doc => 'the arguments to use in a space delimited quoted string; minimum requirements for gmt analysis auto-msa apply',
        },
    ],
    doc => "gmt analysis auto-msa -ace-fof ace.fof"
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

    my $cmd = $self->command_name;
    my $args = $self->args;

    my $dir = $build->data_directory;

    my $exit_code = system "$cmd $args >$dir/output 2>$dir/errors";
    $exit_code /= 256;
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

