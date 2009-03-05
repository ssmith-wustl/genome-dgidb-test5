package Genome::Model::Build::ImportedAnnotation;

use strict;
use warnings;

use Genome;

class Genome::Model::Build::ImportedAnnotation {
    is => 'Genome::Model::Build',
};

sub _get_window{
    my $self = shift;
    my $chromosome = shift;

    my $iter = Genome::Transcript->create_iterator(where => [ chrom_name => $chromosome, build_id => $self->build_id] );
    my $window =  Genome::Utility::Window::Transcript->create ( iterator => $iter, range => 50000);
    return $window
}

sub _get_annotator_for_chromosome {
    my $self = shift;
    my $chromosome = shift;

    my $window = $self->_get_window($chromosome);
    my $annotator = $self->_get_annotator($window);

    unless ($annotator) {
        $self->error_message("Failed to get annotator in _get_annotator_for_chromosome");
        die;
    }

    return $annotator;
}

sub _get_annotator {
    my ($self, $transcript_window) = @_;

    my $annotator = Genome::Utility::AnnotateChromosome->create(
        transcript_window => $transcript_window,
        benchmark => 1,
    );
    die unless $annotator;

    return $annotator;
}

1;

