package Genome::ProcessingProfile::SomaticValidation;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::SomaticValidation {
    is => 'Genome::ProcessingProfile',
    has_param_optional => [
        high_confidence_p_value => {
            is => 'Number', doc => 'p-value threshold for considering a variant "high-confidence"',
        },
        high_confidence_maximum_normal_frequency => {
            is => 'Number', doc => 'maximum frequency in the normal for considering a variant "high-confidence"',
        },
        high_confidence_minimum_tumor_frequency => {
            is => 'Number', doc => 'minimum frequency in the tumor for considering a variant "high-confidence"',
        },
        minimum_coverage => {
            is => 'Number', doc => 'minimum coverage to call a site',
        },
        output_plot => {
            is => 'Boolean', doc => 'include output plot in final results',
        },
        samtools_version => {
            is => 'Text', doc => 'version of samtools to use',
        },
        strand_filter_min_strandedness => {
            is => 'Text', doc => 'Minimum representation of variant allele on each strand',
        },
        strand_filter_min_var_freq => {
            type => 'Text', doc => 'Minimum variant allele frequency',
        },
        strand_filter_min_var_count => {
            type => 'Text', doc => 'Minimum number of variant-supporting reads',
        },
        strand_filter_min_read_pos => {
            type => 'String', doc => 'Minimum average relative distance from start/end of read',
        },
        strand_filter_max_mm_qualsum_diff => {
            type => 'String', doc => 'Maximum difference of mismatch quality sum between variant and reference reads (paralog filter)',
        },
        strand_filter_max_var_mm_qualsum => {
            type => 'String', doc => 'Maximum mismatch quality sum of reference-supporting reads [try 60]',
        },
        strand_filter_max_mapqual_diff => {
            type => 'String', doc => 'Maximum difference of mapping quality between variant and reference reads',
        },
        strand_filter_max_readlen_diff => {
            type => 'String', doc => 'Maximum difference of average supporting read length between variant and reference reads (paralog filter)',
        },
        strand_filter_min_var_dist_3 => {
            type => 'String', doc => 'Minimum average distance to effective 3prime end of read (real end or Q2) for variant-supporting reads',
        },
        strand_filter_min_homopolymer => {
            type => 'String', doc => 'Minimum length of a flanking homopolymer of same base to remove a variant',
        },
        strand_filter_prepend_chr => {
            is => 'Boolean', doc => 'prepend the string "chr" to chromosome names. This is primarily used for external/imported bam files.',
        },
        varscan_params => {
            is => 'String', doc => 'Options to pass to Varscan (e.g. "--min-var-freq 0.08 --p-value 0.10 --somatic-p-value 0.01 --validation 1 --min-coverage 8")',
        },
        varscan_version => {
            is => 'String', doc => 'Version of Varscan to use',
        }
    ],
};

sub _resolve_workflow_for_build {
    my $self = shift;
    my $build = shift;

    my $operation = Workflow::Operation->create_from_xml(__FILE__ . '.xml');

    my $log_directory = $build->log_directory;
    $operation->log_dir($log_directory);
    $operation->name($build->workflow_name);

    return $operation;
}


sub _map_workflow_inputs {
    my $self = shift;
    my $build = shift;

    my @inputs = ();

    # Verify the somatic model
    my $model = $build->model;
    unless ($model) {
        $self->error_message("Failed to get a model for this build!");
        die $self->error_message;
    }

    my $tumor_build = $build->tumor_build;
    my $normal_build = $build->normal_build;

    unless ($tumor_build) {
        $self->error_message("Failed to get a tumor_build associated with this somatic capture build!");
        die $self->error_message;
    }

    unless ($normal_build) {
        $self->error_message("Failed to get a normal_build associated with this somatic capture build!");
        die $self->error_message;
    }

    my $variant_list = $model->variant_list_file;
    unless($variant_list) {
        $self->error_message('Failed to get a variant list for this build!');
        die $self->error_message;
    }

    my $data_directory = $build->data_directory;
    unless ($data_directory) {
        $self->error_message("Failed to get a data_directory for this build!");
        die $self->error_message;
    }

    my $tumor_bam = $tumor_build->whole_rmdup_bam_file;
    unless (-e $tumor_bam) {
        $self->error_message("Tumor bam file $tumor_bam does not exist!");
        die $self->error_message;
    }

    my $normal_bam = $normal_build->whole_rmdup_bam_file;
    unless (-e $normal_bam) {
        $self->error_message("Normal bam file $normal_bam does not exist!");
        die $self->error_message;
    }

    my $reference_sequence_build = $model->reference_sequence_build;
    unless($reference_sequence_build) {
        $self->error_message("Failed to get a reference sequence build for this model!");
        die $self->error_message;
    }
    my $reference_fasta = $reference_sequence_build->sequence_path('fa');
    unless(Genome::Sys->check_for_path_existence($reference_fasta)) {
        $self->error_message('Could not find reference FASTA for specified reference sequence.');
        die $self->error_message;
    }

    push @inputs,
        build_id => $build->id,
        normal_bam_file => $normal_bam,
        tumor_bam_file => $tumor_bam,
        variant_list => $variant_list,
        data_directory => $data_directory,
        reference_fasta => $reference_fasta,
        ;

    my %default_filenames = $self->default_filenames;
    for my $param (keys %default_filenames) {
        my $default_filename = $default_filenames{$param};
        push @inputs,
            $param => join('/', $data_directory, $default_filename);
    }

    push @inputs,
        high_confidence_p_value => (defined $self->high_confidence_p_value ? $self->high_confidence_p_value : 0.01),
        high_confidence_maximum_normal_frequency => (defined $self->high_confidence_maximum_normal_frequency ? $self->high_confidence_maximum_normal_frequency : 4),
        high_confidence_minimum_tumor_frequency => (defined $self->high_confidence_minimum_tumor_frequency ? $self->high_confidence_minimum_tumor_frequency : 15),
        minimum_coverage => (defined $self->minimum_coverage ? $self->minimum_coverage : 0),
        samtools_version => (defined $self->samtools_version ? $self->samtools_version : 'r599'),
        varscan_version => (defined $self->varscan_version ? $self->varscan_version : '2.2.4'),
        varscan_params => (defined $self->varscan_params ? $self->varscan_params : '--min-var-freq 0.08 --p-value 0.10 --somatic-p-value 0.01 --validation 1 --min-coverage 8'),
        output_plot => (defined $self->output_plot ? $self->output_plot : 1),
        ;

    push @inputs,
        strand_filter_min_strandedness => (defined $self->strand_filter_min_strandedness ? $self->strand_filter_min_strandedness : 0.01),
        strand_filter_min_var_freq => (defined $self->strand_filter_min_var_freq ? $self->strand_filter_min_var_freq : 0.05),
        strand_filter_min_var_count => (defined $self->strand_filter_min_var_count ? $self->strand_filter_min_var_count : 4),
        strand_filter_min_read_pos => (defined $self->strand_filter_min_read_pos ? $self->strand_filter_min_read_pos : 0.10),
        strand_filter_max_mm_qualsum_diff => (defined $self->strand_filter_max_mm_qualsum_diff ? $self->strand_filter_max_mm_qualsum_diff : 50),
        strand_filter_max_var_mm_qualsum => (defined $self->strand_filter_max_var_mm_qualsum ? $self->strand_filter_max_var_mm_qualsum : 0),
        strand_filter_max_mapqual_diff => (defined $self->strand_filter_max_mapqual_diff ? $self->strand_filter_max_mapqual_diff : 30),
        strand_filter_max_readlen_diff => (defined $self->strand_filter_max_readlen_diff ? $self->strand_filter_max_readlen_diff : 25),
        strand_filter_min_var_dist_3 => (defined $self->strand_filter_min_var_dist_3 ? $self->strand_filter_min_var_dist_3 : 0.20),
        strand_filter_min_homopolymer => (defined $self->strand_filter_min_homopolymer ? $self->strand_filter_min_homopolymer : 5),
        strand_filter_prepend_chr => (defined $self->strand_filter_prepend_chr ? $self->strand_filter_prepend_chr : 0),
        ;

    return @inputs;
}

sub default_filenames{
    my $self = shift;

    my %default_filenames = (
        varscan_validation_snv => 'validation.varscan.snp',
        varscan_validation_indel => 'validation.varscan.indel',
        filtered_varscan_validation_snv_somatic => 'validation.varscan.snp.Somatic.strandfilter',
        targeted_snv_validation => 'targeted.snvs.validation',
        snv_list_file => 'variant_list.snvs', 
    );

    return %default_filenames;
}

1;
