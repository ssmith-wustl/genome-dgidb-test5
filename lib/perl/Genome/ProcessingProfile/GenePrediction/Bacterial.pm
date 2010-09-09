package Genome::ProcessingProfile::GenePrediction::Bacterial;

use strict;
use warnings;

use Genome;
use Carp;

class Genome::ProcessingProfile::GenePrediction::Bacterial {
    is => 'Genome::ProcessingProfile::GenePrediction',
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
            is => 'Number',
            doc => 'Number of runners for the gene prediction step',
            is_optional => 1,
            default => 50,
        }, 
        skip_acedb_parse => {
            is => 'Boolean',
            doc => 'If set, skip aceDB parsing in bap project finish',
            is_optional => 1,
            default => 0,
        },
    ],
    doc => "Processing profile for gene prediction and merging models"
};

sub _resolve_type_name_for_class {
    return "gene prediction bacterial";
}

sub _execute_build {
    my ($self, $build) = @_;

    my $model = $build->model;
    $self->status_message("Executing build logic for " . $self->__display_name__ . ":" . $build->__display_name__);

    # TODO Make explicit build links between this build and the assembly build for tracking

    my $config_file_path = $build->create_config_file;
    unless (-s $config_file_path) {
        $self->error_message("Configuration file not found at expected location: $config_file_path");
        croak;
    }

    $self->status_message("Configuration file created at $config_file_path, creating hap command object");

    my $hap_object = Genome::Model::Tools::Hgmi::Hap->create(
        config => $config_file_path,
        dev => $model->dev,
        skip_core_check => $self->skip_core_gene_check,
        skip_protein_annotation => 1, # TODO Eventually, this build process will include PAP and BER
    );
    unless ($hap_object) {
        $self->error_message("Could not create hap command object!");
        croak;
    }

    $self->status_message("Hap command object created, executing!");

    my $hap_rv = $hap_object->execute;
    unless ($hap_rv) {
        $self->error_message("Trouble executing hap command!");
        croak;
    }
   
    $DB::single = 1;
    my @changed_objects = (
        UR::Context->all_objects_loaded('UR::Object::Ghost'),
        grep { $_->__changes__ } UR::Context->all_objects_loaded('UR::Object')
    );
    use IO::File;
    use Data::Dumper;
    my $fh = IO::File->new("/gscuser/bdericks/objects.txt", "w");
    $fh->print(Dumper(\@changed_objects));
    $fh->close;

    $self->status_message("Hap executed and no problems detected!");
    return 1;
}

1;


