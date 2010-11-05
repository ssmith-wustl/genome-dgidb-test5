package Genome::Model::GenePrediction::Eukaryotic;

use strict;
use warnings;
use Genome;

class Genome::Model::GenePrediction::Eukaryotic {
    is => 'Genome::Model::GenePrediction',
    has => [
        # Processing profile params
        max_bases_per_fasta => {
            via => 'processing_profile',
        },
        xsmall => {
            via => 'processing_profile',
        },
        rnammer_version => {
            via => 'processing_profile',
        },
        rfamscan_version => {
            via => 'processing_profile',
        },
        snap_version => {
            via => 'processing_profile',
        },
        skip_masking_if_no_rna => {
            via => 'processing_profile',
        },
    ],
    has_optional => [
        repeat_library => {
            is => 'String',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'repeat_library' ],
        },
        snap_models => {
            is => 'String',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'snap_models' ],
        },
        fgenesh_model => {
            is => 'String',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'fgenesh_model' ],
        },
    ],
};

sub create {
    my $class = shift;
    my %params = @_;

    # Anything left in the params hash will be made into an input on the model
    my $self = $class->SUPER::create(
        name                             => delete $params{name},
        processing_profile_id            => delete $params{processing_profile_id},
        subject_name                     => delete $params{subject_name},
        subject_type                     => delete $params{subject_type},
        subject_id                       => delete $params{subject_id},
        subject_class_name               => delete $params{subject_class_name},
        auto_assign_inst_data            => delete $params{auto_assign_inst_data},
        auto_build_alignments            => delete $params{auto_build_alignments},
        create_assembly_model            => delete $params{create_assembly_model},
        assembly_processing_profile_name => delete $params{assembly_processing_profile_name},
        start_assembly_build             => delete $params{start_assembly_build},
        assembly_contigs_file            => delete $params{assembly_contigs_file},
    );
    return unless $self;

    # Add inputs to the model
    for my $key (keys %params) {
        $self->add_input(
            value_class_name => 'UR::Value',
            value_id => $params{$key},
            name => $key,
        );
    }

    return $self;
}

1;

