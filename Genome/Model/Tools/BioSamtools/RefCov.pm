package Genome::Model::Tools::BioSamtools::RefCov;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::BioSamtools::RefCov {
    is => ['Genome::Model::Tools::BioSamtools'],
    has_input => [
        bam_file => {
            doc => 'A BAM file, sorted and indexed, containing alignment/read data',
        },
        bed_file => {
            doc => 'The BED format file (tab delimited: chr,start,end,name) file containing annotation or regions of interest.',
        },
        output_directory => {
            doc => 'When run in parallel, this directory will contain all output and intermediate STATS files. Do not define if stats_file is defined.',
            is_optional => 1
        },
        min_depth_filter => {
            doc => 'The minimum depth at each position to consider coverage.',
            default_value => 1,
            is_optional => 1,
        },
        wingspan => {
            doc => 'A base pair wingspan value to add +/- of the input regions',
            default_value => 0,
            is_optional => 1,
        },
    ],
    has_output => [
        stats_file => {
            doc => 'When run in parallel, do not define.  From the command line this file will contain the output metrics for each region.',
            is_optional => 1,
        },
    ],
    has_param => [
        lsf_queue => {
            doc => 'When run in parallel, the LSF queue to submit jobs to.',
            is_optional => 1,
            default_value => 'long',
        },
        lsf_resource => {
            doc => 'When run in parallel, the resource request necessary to run jobs on LSF.',
            is_optional => 1,
            default_value => "-R 'select[type==LINUX64]'",
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

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    if ($self->output_directory) {
        if ($self->stats_file) {
            die('No need to define stats_file when output_directory is defined');
        }
    } elsif (!defined($self->stats_file)) {
        die ('Must define stats_file or output_directory');
    }
    return $self;
}

sub execute {
    my $self = shift;

    if ($self->output_directory) {
        unless (-e $self->output_directory){
            Genome::Utility::FileSystem->create_directory($self->output_directory);
        }
    }
    unless ($self->stats_file) {
        my ($bam_basename,$bam_dirname,$bam_suffix) = File::Basename::fileparse($self->bam_file,qw/.bam/);

        my ($regions_basename,$regions_dirname,$regions_suffix) = File::Basename::fileparse($self->bed_file,qw/.bed/);
        $self->stats_file($self->output_directory .'/'. $bam_basename .'_'. $regions_basename .'_STATS.tsv');
    }
    my $cmd = $self->execute_path .'/bed_refcov-64.pl '. $self->bam_file .' '. $self->bed_file .' '. $self->stats_file .' '. $self->min_depth_filter .' '. $self->wingspan;
    Genome::Utility::FileSystem->shellcmd(
        cmd => $cmd,
        input_files => [$self->bam_file,$self->bed_file],
        output_files => [$self->stats_file],
    );
    return 1;
}

1;
