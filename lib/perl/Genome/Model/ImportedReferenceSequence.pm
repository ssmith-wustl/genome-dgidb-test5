package Genome::Model::ImportedReferenceSequence;
#:adukes see G:M:B:ImportedReferenceSequence, this needs to be expanded beyond use for ImportedAnnotation tasks only

use strict;
use warnings;

use Genome;

class Genome::Model::ImportedReferenceSequence {
    is => 'Genome::Model',
};

sub build_by_version {
    my $self = shift;
    my $version = shift;
    my @b = Genome::Model::Build::ImportedReferenceSequence->get('type_name' => 'imported reference sequence',
                                                                 'version' => $version,
                                                                 'model_id' => $self->genome_model_id);
    if (@b > 1) {
        die "Multiple builds for version $version for model " . $self->genome_model_id;
    }
    return $b[0];
}

1;
