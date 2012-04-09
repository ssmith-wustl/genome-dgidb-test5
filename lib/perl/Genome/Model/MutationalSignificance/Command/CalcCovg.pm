package Genome::Model::MutationalSignificance::Command::CalcCovg;

use strict;
use warnings;

use Genome;

class Genome::Model::MutationalSignificance::Command::CalcCovg {
    is => ['Command::V2'],
    has_input => [
        somatic_variation_build => {
            is => 'Genome::Model::Build::SomaticVariation',
            doc => 'Build for sample to use for coverage calculation',
        },
        output_dir => {
            is => 'Text',
            is_output => 1,
            doc => "Directory where output files and subdirectories will be written",
        },
        reference_sequence => {
            is => 'Text',
            doc => "Path to reference sequence in FASTA format",
        },
        normal_min_depth => {
            is => 'Text',
            is_optional => 1,
            doc => "The minimum read depth to consider a Normal BAM base as covered",
        },
        tumor_min_depth => {
            is => 'Text',
            is_optional => 1,
            doc => "The minimum read depth to consider a Tumor BAM base as covered",
        },
        min_mapq => {
            is => 'Text',
            is_optional => 1,
            doc => "The minimum mapping quality of reads to consider towards read depth counts",
        },
        roi_file => {
            is => 'Text',
            doc => "Tab delimited list of ROIs [chr start stop gene_name] (See Description)",
        },
    ],
    has_output => [
        output_file => {
            is => 'Text',
            doc => 'Path to gene coverage file for this sample',
        },
    ],
};

sub help_synopsis {
    return <<HELP
This module calculates per-feature coverage for a sample, given the somatic variation build of that sample.
General usage:

 genome model mutational-significance calc-covg \\
    --bam-list input_dir/bam_list \\
    --output-dir output_dir/ \\
    --reference-sequence input_dir/all_sequences.fa \\
    --roi-file input_dir/all_coding_exons.tsv \\
    --somatic-variation-build BUILD

HELP
}

sub help_detail {
    return <<HELP;
This module wraps the MuSiC calc-covg tool to calculate coverage for a single sample.
The base counts are taken from the tumor and normal bam files in the somatic variation build.
For more details on the calculation, see gmt music bmr calc-covg --help
HELP
}

sub execute {
    my $self = shift;

    $self->status_message("CalcCovg for build ".$self->somatic_variation_build->id);

    my $normal_bam = $self->somatic_variation_build->normal_bam;
    my $tumor_bam = $self->somatic_variation_build->tumor_bam;

    my $sample_name = $self->somatic_variation_build->tumor_build->model->subject->extraction_label;

    my $output_dir = $self->output_dir."/roi_covgs";

    unless (-d $output_dir) {
        Genome::Sys->create_directory($output_dir);
    }

    my $output_file = $output_dir."/".$sample_name.".covg";

    $self->output_file($output_file);

    my $cmd = Genome::Model::Tools::Music::Bmr::CalcCovgHelper->create (
        roi_file => $self->roi_file,
        reference_sequence => $self->reference_sequence,
        normal_bam => $normal_bam,
        tumor_bam => $tumor_bam,
        output_file => $output_file,
    );
    if ($self->normal_min_depth) {
        $cmd->normal_min_depth($self->normal_min_depth);
    }
    if ($self->tumor_min_depth) {
        $cmd->tumor_min_depth($self->tumor_min_depth);
    }
    if ($self->min_mapq) {
        $cmd->min_mapq($self->min_mapq);
    }
    $cmd->execute;

    my $status = "CalcCovg done";
    $self->status_message($status);
    return 1;
}

1;
