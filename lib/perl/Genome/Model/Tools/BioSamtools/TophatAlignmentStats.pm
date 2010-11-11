package Genome::Model::Tools::BioSamtools::TophatAlignmentStats;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::BioSamtools::TophatAlignmentStats {
    is  => 'Genome::Model::Tools::BioSamtools',
    has_input => [
        unaligned_bam_file => {
            is => 'String',
            doc => 'An unaligned BAM file querysorted with ALL reads from original FASTQ files.',
        },
        aligned_bam_file => {
            is => 'String',
            doc => 'A querysorted BAM file containing Tophat alignments.',
        },
        merged_bam_file => {
            is => 'String',
            doc => 'The path to output the resulting merged, unsorted BAM file.',
        },
        alignment_stats_file => {
            is => 'String',
            doc => 'A summary file of some calculated BAM alignment metrics.',
        },
    ],
};

sub help_synopsis {
    return <<EOS
    A Tophat based utility for alignment metrics.
EOS
}

sub help_brief {
    return <<EOS
    A Tophat based utility for alignment metrics.
EOS
}

sub help_detail {
    return <<EOS
--->Add longer docs here<---
EOS
}

sub execute {
    my $self = shift;
    my $cmd = $self->bin_path .'/tophat_unaligned.pl '. $self->unaligned_bam_file
        .' '. $self->aligned_bam_file
            .' '. $self->merged_bam_file
                .' > '. $self->alignment_stats_file;
    Genome::Utility::FileSystem->shellcmd(
        cmd => $cmd,
        input_files => [$self->unaligned_bam_file,$self->aligned_bam_file],
        output_files => [$self->merged_bam_file,$self->alignment_stats_file],
        skip_if_output_is_present => 0,
    );
    return 1;
}

1;
