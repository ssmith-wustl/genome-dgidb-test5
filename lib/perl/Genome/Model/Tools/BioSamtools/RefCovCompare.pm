package Genome::Model::Tools::BioSamtools::RefCovCompare;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::BioSamtools::RefCovCompare {
    is => ['Genome::Model::Tools::BioSamtools'],
    has_input => [
        bam_file_a => {
            doc => 'A BAM file, sorted and indexed, containing alignment/read data',
        },
        bam_file_b => {
            doc => 'A BAM file, sorted and indexed, containing alignment/read data',
        },
        bed_file => {
            doc => 'The BED format file (tab delimited: chr,start,end,name) file containing annotation or regions of interest.',
        },
        output_file => {
            doc => 'The path where an output file will be written with A<->B coverage comparison',
        },
        min_depth_filter => {
            doc => 'The minimum depth at each position to consider coverage.',
            default_value => 1,
            is_optional => 1,
        },
    ],
};

sub help_detail {
'
These commands are setup to run perl v5.10.0 scripts that use Bio-Samtools and require bioperl v1.6.0.  They all require 64-bit architecture.

Output file format:
[1] Region Name (column 4 of BED file)
[2] Region Length
[3] AB - Missing Base Pair
[4] AB - Percent Missing Base Pair
[5] AB - Total Covered Base Pair
[6] AB - Percent Total Covered Base Pair
[7] AB - Unique Covered Base Pair
[8] AB - Perecent Unique Covered Base Pair
[9] A - Total Covered Base Pair
[10] A - Percent Total Covered Base Pair
[11] A - Unique Covered Base Pair
[12] A - Percent Unique Covered Base Pair
[13] B - Total Covered Base Pair
[14] B - Percent Total Covered Base Pair
[15] B - Unique Covered Base Pair
[16] B - Percent Unique Covered Base Pair

'
}


sub execute {
    my $self = shift;

    my $cmd = $self->execute_path .'/refcov_compare-64.pl '. $self->bam_file_a .' '. $self->bam_file_b .' '. $self->bed_file .' '. $self->output_file .' '. $self->min_depth_filter;
    Genome::Utility::FileSystem->shellcmd(
        cmd => $cmd,
        input_files => [$self->bam_file_a,$self->bam_file_b,$self->bed_file],
        output_files => [$self->output_file],
        skip_if_output_is_present => 0,
    );
    return 1;
}

1;
