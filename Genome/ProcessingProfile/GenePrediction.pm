package Genome::ProcessingProfile::GenePrediction;

use strict;
use warnings;

use Genome;
use Carp;

class Genome::ProcessingProfile::GenePrediction {
    is => 'Genome::ProcessingProfile',
    has_param => [
        skip_core_gene_check => {
            is => 'Boolean',
            doc => 'If set, the core gene check is not performed',
            is_optional => 1,
            default => 0,
        },
        minimum_sequence_length => {
            is => 'Number',
            doc => 'Minimum contig sequence length',
            is_optional => 1,
            default => 200,
        },
        runner_count => {
            doc => 'Number of runners for the gene prediction step',
            is_optional => 1,
            default => 50,
        }, 
        skip_acedb_parse => {
            doc => 'If set, skip aceDB parsing in bap project finish',
            is_optional => 1,
            default => 0,
        },
    ],
    doc => "Processing profile for gene prediction and merging models"
};

sub _execute_build {
    my ($self, $build) = @_;
    $self->status_message("Executing build logic for " . $self->__display_name__ . ":" . $build->__display_name__);

    my $model = $build->model;

    my $config_file = $build->create_yaml_file;
    unless (-s $config_file) {
        $self->error_message("Error creating configuration file!");
        croak;
    }
    $self->status_message("Configuration file generated and stored at $config_file");

    return 1;
    my $hap_obj = Genome::Model::Tools::Hgmi::Hap->create(
        config => $config_file,
        dev => $model->dev,
        skip_core_check => $self->skip_core_gene_check,
        skip_protein_annotation => 1,
    );
    unless ($hap_obj) {
        $self->error_message("Could not create Hap command object!");
        croak;
    }

    my $rv = $hap_obj->execute;
    unless ($rv) {
        $self->error_message("Problems executing Hap command!");
        croak;
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


