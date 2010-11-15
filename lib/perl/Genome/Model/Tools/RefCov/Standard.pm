package Genome::Model::Tools::RefCov::Standard;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::RefCov::Standard {
    is => ['Genome::Model::Tools::RefCov'],
};

sub help_detail {
'
These commands are setup to run perl v5.10.0 scripts that use Bio-Samtools and require bioperl v1.6.0.  They all require 64-bit architecture.

Output file format(stats_file):
[1] Region Name (column 4 of BED file)
[2] Percent of Reference Bases Covered
[3] Total Number of Reference Bases
[4] Total Number of Covered Bases
[5] Number of Missing Bases
[6] Average Coverage Depth
[7] Standard Deviation Average Coverage Depth
[8] Median Coverage Depth
[9] Number of Gaps
[10] Average Gap Length
[11] Standard Deviation Average Gap Length
[12] Median Gap Length
[13] Min. Depth Filter
[14] Discarded Bases (Min. Depth Filter)
[15] Percent Discarded Bases (Min. Depth Filter)
';
}

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


