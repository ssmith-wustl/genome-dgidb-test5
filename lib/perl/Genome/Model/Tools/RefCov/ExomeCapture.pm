package Genome::Model::Tools::RefCov::ExomeCapture;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::RefCov::ExomeCapture {
    is => ['Genome::Model::Tools::RefCov'],
    has => [
        min_depth_filter => {
            default_value => '1,5,10,15,20',
            is_optional => 1,
        },
        evaluate_gc_content => {
            default_value => 1,
            is_optional => 1,
        },
        roi_normalized_coverage => {
            default_value => 1,
            is_optional => 1,
        },
    ],
};

sub execute {
    my $self = shift;

    return 1;
}

1;
