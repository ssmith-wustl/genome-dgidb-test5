package Genome::Model::Build::ImportedAnnotation;

use strict;
use warnings;

use Genome;

class Genome::Model::Build::ImportedAnnotation {
    is => 'Genome::Model::Build',
};

sub annotation_data_directory{
    my $self = shift;
    return $self->data_directory."/annotation_data";
}

1;

