package Genome::Model::Tools::RefCov::Standard;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::RefCov::Standard {
    is => ['Genome::Model::Tools::RefCov'],
};

sub help_brief {
    "The default standard for running RefCov.",
}

sub execute {
    my $self = shift;
    unless ($self->print_roi_coverage) {
        die('Failed to print ROI coverage!');
    }
    return 1;
}


1;


