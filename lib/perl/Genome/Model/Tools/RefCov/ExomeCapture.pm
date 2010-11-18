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
        print_headers => {
            default_value => 1,
            is_optional => 1,
        },
    ],
};

sub execute {
    my $self = shift;
    unless ($] > 5.012) {
        die "Bio::DB::Sam requires perl 5.12!";
    }
    require Bio::DB::Sam;
    # This is only necessary when run in parallel
    $self->resolve_final_directory;

    # This is only necessary when run in parallel or only an output_directory is defined in params(ie. no stats_file)
    $self->resolve_stats_file;

    unless ($self->print_standard_roi_coverage) {
        die('Failed to print stats to file '. $self->stats_file);
    }
    return 1;
}

1;
