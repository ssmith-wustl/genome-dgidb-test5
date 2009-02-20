package Genome::Model::ImportedAnnotation;

use strict;
use warnings;

use Genome;

class Genome::Model::ImportedAnnotation{
    is => 'Genome::Model',
    has =>[
        processing_profile => {
            is => 'Genome::ProcessingProfile::ImportedAnnotation',
            id_by => 'processing_profile_id',
        },
        reference_sequence_build => {
            is => 'Genome::Model::ImportedReferenceSequence', #TODO, should this just be Genome::Model?
            via => 'processing_profile'
        },
    ],
};


sub build_by_version {
    my $self = shift;
    my $version = shift;
    my @b = $self->builds("data_directory like" => "%/v${version}_%");
    if (@b > 1) {
        die "Multiple builds for version $version for model " . $self->model_id;
    }
    return $b[0];
}

1;

