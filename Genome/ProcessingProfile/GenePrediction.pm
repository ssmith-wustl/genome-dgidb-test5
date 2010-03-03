package Genome::ProcessingProfile::GenePrediction;

use strict;
use warnings;
use Genome;
use Carp;

class Genome::ProcessingProfile::GenePrediction {
    is => 'Genome::ProcessingProfile',
    has_param => [
#        command_name => {
#            doc => 'the name of a single command to run',
#        },
        args => {
            is_optional => 1,
            doc => 'the arguments to use',
        },
        config_file => {
            is => "String",
            doc => "yaml file for gene prediction pipeline; eventually, we'll blow this up and use the options directly...",
        },
        
    ],
    doc => "gene prediction processing profile..."
};

sub _initialize_model {
    my ($self,$model) = @_;
    carp "defining new model " . $model->__display_name__ . " for profile " . $self->__display_name__ . "\n";
    return 1;
}

sub _initialize_build {
    my ($self,$build) = @_;
    carp "defining new build " . $build->__display_name__ . " for profile " . $self->__display_name__ . "\n";
    return 1;
}

sub _execute_build {
    my ($self,$build) = @_;
    carp "executing build logic for " . $self->__display_name__ . ':' .  $build->__display_name__ . "\n";

    #my $cmd = $self->command_name;
    my $cmd = "gmt hgmi hap";
    my $config = $self->config_file;
    my $args = $self->args;

    my $dir = $build->data_directory;

    # instead of nasty system(), we should pull in the stuff from dir build
    # mk prediction models, collect/name sequence, bap gene predict,
    # bap gene merge, bap_project_finish, rrna screen, core gene check
    my $exit_code = system "$cmd --config $config --skip-protein-annotation $args >$dir/output 2>$dir/errors";
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

