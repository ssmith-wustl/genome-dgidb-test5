package Genome::Model::Tools::BioSamtools::RelativeCoverage;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::BioSamtools::RelativeCoverage {
    is => ['Genome::Model::Tools::BioSamtools'],
    has_input => [
        bam_file => {
            doc => 'A BAM file, sorted and indexed, containing alignment/read data',
        },
        bed_file => {
            doc => 'The BED format file (tab delimited: chr,start,end,name) file containing annotation or regions of interest.',
        },
        stats_file => {
            doc => 'When run in parallel, do not define.  From the command line this file will contain the output metrics for each region.',
            is_optional => 1,
        },
        bias_file => {
            doc => 'When run in parallel, do not define.  From the command line this file will contain the output metrics for each region.',
            is_optional => 1,
        },
    ],
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
    unless (Genome::Config->arch_os =~ /64/) {
        die('Failed to run on 64-bit architecture');
    }
    my $cmd = $self->execute_path .'/refcov-w_bias-64.pl '. $self->bam_file .' '. $self->bed_file .' '. $self->stats_file .' '. $self->bias_file;
    Genome::Utility::FileSystem->shellcmd(
        cmd => $cmd,
        input_files => [$self->bam_file,$self->bed_file],
        output_files => [$self->stats_file],
    );
    return 1;
}

1;
