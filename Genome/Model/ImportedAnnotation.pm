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
    my @b =  grep { $_->version eq $version} $self->builds;
    if (@b > 1) {
        die "Multiple builds for version $version for model " . $self->genome_model_id;
    }
    return $b[0];
}

sub annotation_data_directory{
    my $self = shift;
    my $build = $self->last_complete_build;
    return $build->annotation_data_directory;
}

1;

