package Genome::Model::Tools::RefCov::RnaSeq;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::RefCov::RnaSeq {
    is => ['Genome::Model::Tools::RefCov'],
    has => [
        print_headers => {
            is_optional => 1,
            default_value => 1,
        },
        merged_stats_file => {
            is_optional => 0,
        },
        merge_by => {
            is_optional => 1,
            default_value => 'transcript',
        },
        alignment_count => {
            default_value => 1,
            is_optional => 1,
        },
        print_min_max => {
            default_value => 1,
            is_optional => 1,
        },
    ],
};

sub help_brief {
    "The default for running RefCov on RNA-seq BAMs.  Includes merged results by transcript and normalized coverage by ROI.",
}

sub execute {
    my $self = shift;
    unless ($self->print_roi_coverage) {
        die('Failed to print ROI coverage!');
    }
    return 1;
}

1;
