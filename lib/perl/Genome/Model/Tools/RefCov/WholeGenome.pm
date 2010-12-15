package Genome::Model::Tools::RefCov::WholeGenome;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::RefCov::WholeGenome {
    is => ['Genome::Model::Tools::RefCov'],
    has_input => [
        merged_stats_file => {
            is => 'Text',
            doc => 'The final merged stats file',
        },
        merge_by => {
            is => 'Text',
            is_optional => 1,
            default_value => 'transcript',
            valid_values => ['exome','gene','transcript'],
        },
    ],
};

sub help_detail {
    '
These commands are setup to run perl v5.10.0 scripts that use Bio-Samtools and require bioperl v1.6.0.  They all require 64-bit architecture.
';
}

sub execute {
    my $self = shift;
    unless ($] > 5.012) {
        die "Bio::DB::Sam requires perl 5.12!";
    }
    require Bio::DB::Sam;
    # This is only necessary when run in parallel
    $self->resolve_final_directory();

    # This is only necessary when run in parallel or only an output_directory is
    # defined in params(ie. no stats_file)
    $self->resolve_stats_file();

    unless ($self->print_standard_roi_coverage()) {
        die( 'Failed to print stats to file '. $self->stats_file() );
    }

    # WholeGenome assumes we will be evaluating gene (exon) annotation ROI in
    # context of whole genome alignments (e.g., BWA produced BAMs). We will be
    # stitching the exons back together on a gene-by-gene basis.
    $self->merge_stats_by($self->merge_by,$self->merged_stats_file);

    return 1;
}

1;  # end of package
