package Genome::Model::GenotypeMicroarray;

use strict;
use warnings;

use Genome;
use File::Basename;
use Sort::Naturally;
use IO::File;

class Genome::Model::GenotypeMicroarray{
    is => 'Genome::Model',
    has => [
        input_format    => { via => 'processing_profile' },
        instrument_type => { via => 'processing_profile' },
        reference_sequence_build_id => {
            is => 'Text',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'reference_sequence_build', value_class_name => 'Genome::Model::Build::ImportedReferenceSequence' ],
            is_many => 0,
            is_mutable => 1, # TODO: make this non-optional once backfilling is complete and reference placeholder is deleted
            is_optional => 1,
            doc => 'reference sequence to align against'
        },
        reference_sequence_build => {
            is => 'Genome::Model::Build::ImportedReferenceSequence',
            id_by => 'reference_sequence_build_id',
        },
        dbsnp_build_id => {
            is => 'Text',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'dbsnp_build', value_class_name => 'Genome::Model::Build::ImportedVariationList' ],
            is_many => 0,
            is_mutable => 1,
            is_optional => 1,
            doc => 'dbsnp build that this model is built against'
        },
        dbsnp_build => {
            is => 'Genome::Model::Build::ImportedVariationList',
            id_by => 'dbsnp_build_id',
        },
    ],
};

sub sequencing_platform { return 'genotype file'; }

sub default_model_name {
    my $self = shift;
    return $self->SUPER::default_model_name . " " . $self->reference_sequence_build->name;
}

1;
