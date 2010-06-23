package Genome::Model::Tools::Somatic::Compare::Bams;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Somatic::Compare::Bams {
    is => ['Workflow::Operation::Command'],
    workflow => sub { Workflow::Operation->create_from_xml(\*DATA); }
};

sub help_brief {
    "Runs the somatic pipeline workflow."
}

sub help_synopsis{
    my $self = shift;
    return <<"EOS"
gmt somatic compare bams --normal-bam-file normal.bam --tumor-bam-file tumor.bam --tumor-snp-file tumor.snp --data-directory /some/dir/for/data
EOS
}

sub help_detail {
    my $self = shift;
    return <<"EOS"
This tool runs the somatic pipeline to compare a tumor and a normal for variant detection, structural variation detection, etc.
This tool is called automatically when running a build on a somatic model.  See also 'genome model build somatic'.
EOS
}

sub pre_execute {
    my $self = shift;
    $DB::single=1;

    # If data directory was provided... make sure it exists and set all of the file names
    if ($self->data_directory) {
        unless (-d $self->data_directory) {
            $self->error_message("Data directory " . $self->data_directory . " does not exist. Please create it.");
            return 0;
        }
        
        my %default_filenames = $self->default_filenames;
        for my $param (keys %default_filenames) {
            # set a default param if one has not been specified
            my $default_filename = $default_filenames{$param};
            unless ($self->$param) {
                $self->status_message("Param $param was not provided... generated $default_filename as a default");
                $self->$param($self->data_directory . "/$default_filename");
            }
        }
    }

    # Set (hardcoded) defaults for tools that have defaults that do not agree with somatic pipeline
    unless (defined $self->skip_if_output_present) {
        $self->skip_if_output_present(1);
    }
    unless (defined $self->imported_bams) {
        $self->imported_bams(0);
    }
    unless (defined $self->lookup_variants_report_mode) {
        $self->lookup_variants_report_mode("novel-only");
    }
    # Submitters to exclude from somatic pipeline as per dlarson. These guys submit cancer samples to dbsnp, or somesuch
    unless (defined $self->lookup_variants_filter_out_submitters) {
        $self->lookup_variants_filter_out_submitters("SNP500CANCER,OMIMSNP,CANCER-GENOME,CGAP-GAI,LCEISEN,ICRCG,DEVINE_LAB");
    }
    unless (defined $self->annotate_no_headers) {
        $self->annotate_no_headers(1);
    }
    unless (defined $self->transcript_annotation_filter) {
        $self->transcript_annotation_filter("top");
    }
    unless (defined $self->only_tier_1) {
        $self->only_tier_1(0);
    }

    unless (defined $self->skip_sv) {
        $self->skip_sv(0);
    }
    unless (defined $self->breakdancer_params) {
        $self->breakdancer_params("");
    }
    unless (defined $self->bam2cfg_params) {
        $self->bam2cfg_params("");
    }
    unless (defined $self->breakdancer_version) {
        $self->breakdancer_version("");
    }

    # The output files of indel pe step should go into the workflow directory
    unless (defined $self->normal_indelpe_data_directory) {
        $self->normal_indelpe_data_directory($self->data_directory . "/normal_indelpe_data");
    }
    unless (defined $self->tumor_indelpe_data_directory) {
        $self->tumor_indelpe_data_directory($self->data_directory . "/tumor_indelpe_data");
    }

    # if tumor or normal snp files are provided, we can skip running indelpe on that sample
    if (defined $self->tumor_snp_file) {
        $self->skip_tumor_indelpe(1);
    } else {
        $self->skip_tumor_indelpe(0);
    }
    if (defined $self->normal_snp_file) {
        $self->skip_normal_indelpe(1);
    } else {
        $self->skip_normal_indelpe(0);
    }
    
    # Default ref seq
    unless (defined $self->reference_fasta) {
        $self->reference_fasta(Genome::Config::reference_sequence_directory() . '/NCBI-human-build36/all_sequences.fa');
    }

    # Default high confidence parameters 
    unless (defined $self->min_mapping_quality) {
        $self->min_mapping_quality(70);
    }
    unless (defined $self->min_somatic_quality) {
        $self->min_somatic_quality(40);
    }
    
    # Default dbSnp parameters
    unless (defined $self->require_dbsnp_allele_match) {
        $self->require_dbsnp_allele_match(1);
    }

    # This is kinda hacky, but we need to join the breakdancer and breakdancer config params into one sv_params to pass
    # to breakdancer, since it has to follow a generic API with only one set of params
    my $sv_params = join(":", ($self->breakdancer_params, $self->bam2cfg_params) );

    $self->sv_params($sv_params);
    # Set the operation name so we can later easily access workflow properties by build id
    $self->_operation->name($self->_operation->name . ' Build ' . $self->build_id); 

    return 1;
}

sub default_filenames{
    my $self = shift;
   
    my %default_filenames = (
        breakdancer_working_directory       => 'breakdancer/',
        sniper_working_directory            => 'sniper/',
        snp_filter_output                   => 'sfo_snp_filtered.csv',
        loh_fail_output_file                => 'loh.csv',
        loh_output_file                     => 'noloh.csv',
        filter_ceu_yri_output               => 'ceu_yri_filtered.csv',
        adaptor_output_snp                  => 'adv_adapted_snp.csv',
        dbsnp_output                        => 'dbsnp_filtered.csv',
        annotate_output_snp                 => 'anv_annotated_snp.csv',
        ucsc_output_snp                     => 'uca_ucsc_annotated_snp.csv',
        ucsc_unannotated_output_snp         => 'ucu_ucsc_unannotated_snp.csv',
        tier_1_snp_file                     => 't1v_tier1_snp.csv',
        tier_2_snp_file                     => 't2v_tier2_snp.csv',
        tier_3_snp_file                     => 't3v_tier3_snp.csv',
        tier_4_snp_file                     => 't4v_tier4_snp.csv',
        tier_1_snp_high_confidence_file     => 'hc1_tier1_snp_high_confidence.csv',
        tier_2_snp_high_confidence_file     => 'hc2_tier2_snp_high_confidence.csv',
        tier_3_snp_high_confidence_file     => 'hc3_tier3_snp_high_confidence.csv',
        tier_4_snp_high_confidence_file     => 'hc4_tier4_snp_high_confidence.csv',
        upload_variants_snp_1_output        => 'uv1_uploaded_tier1_snp.csv',
        upload_variants_snp_2_output        => 'uv2_uploaded_tier2_snp.csv',
        indel_lib_filter_multi_output       => 'iml_indel_multi_lib_filtered.csv',
        indel_lib_filter_single_output      => 'isl_indel_single_lib_filtered.csv',
        adaptor_output_indel                => 'adi_adaptor_output_indel.csv',
        annotate_output_indel               => 'ani_annotated_indel.csv',
        ucsc_output_indel                   => 'uci_ucsc_annotated_indel.csv',
        ucsc_unannotated_output_indel       => 'ucn_ucsc_unannotated_indel.csv',
        tier_1_indel_file                   => 't1i_tier1_indel.csv',
        tier_2_indel_file                   => 't2i_tier2_indel.csv',
        tier_3_indel_file                   => 't3i_tier3_indel.csv',
        tier_4_indel_file                   => 't4i_tier4_indel.csv',
        upload_variants_indel_1_output      => 'ui1_uploaded_tier1_indel.csv',
        upload_variants_indel_2_output      => 'ui2_uploaded_tier2_indel.csv',
        copy_number_output                  => 'cno_copy_number.csv',
        circos_graph                        => 'circos_graph.png',
        variant_report_output               => 'cancer_report.html', 
        file_summary_report_output          => 'file_summary_report.html', 
        indel_lib_filter_preferred_output   => 'NULL',
    );

    return %default_filenames;
}

1;
__DATA__
<?xml version='1.0' standalone='yes'?>

<workflow name="Somatic Pipeline" logDir="/gsc/var/log/genome/somatic_pipeline">

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Somatic Sniper" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="normal_bam_file" toOperation="Somatic Sniper" toProperty="control_aligned_reads_input" />
  <link fromOperation="input connector" fromProperty="tumor_bam_file" toOperation="Somatic Sniper" toProperty="aligned_reads_input" />
  <link fromOperation="input connector" fromProperty="reference_fasta" toOperation="Somatic Sniper" toProperty="reference_sequence_input" />
  <link fromOperation="input connector" fromProperty="sniper_working_directory" toOperation="Somatic Sniper" toProperty="working_directory" />
  <link fromOperation="input connector" fromProperty="sniper_version" toOperation="Somatic Sniper" toProperty="version" />
  <link fromOperation="input connector" fromProperty="sniper_params" toOperation="Somatic Sniper" toProperty="snv_params" />
  <link fromOperation="input connector" fromProperty="sniper_params" toOperation="Somatic Sniper" toProperty="indel_params" />

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Breakdancer" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="sv_params" toOperation="Breakdancer" toProperty="sv_params" />
  <link fromOperation="input connector" fromProperty="breakdancer_version" toOperation="Breakdancer" toProperty="version" />
  <link fromOperation="input connector" fromProperty="normal_bam_file" toOperation="Breakdancer" toProperty="control_aligned_reads_input" />
  <link fromOperation="input connector" fromProperty="tumor_bam_file" toOperation="Breakdancer" toProperty="aligned_reads_input" />
  <link fromOperation="input connector" fromProperty="breakdancer_working_directory" toOperation="Breakdancer" toProperty="working_directory" />
  <link fromOperation="input connector" fromProperty="reference_fasta" toOperation="Breakdancer" toProperty="reference_sequence_input" />
  <link fromOperation="input connector" fromProperty="skip_sv" toOperation="Breakdancer" toProperty="skip" />

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Copy Number Alteration" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="normal_bam_file" toOperation="Copy Number Alteration" toProperty="normal_bam_file" />
  <link fromOperation="input connector" fromProperty="tumor_bam_file" toOperation="Copy Number Alteration" toProperty="tumor_bam_file" />
  <link fromOperation="input connector" fromProperty="copy_number_output" toOperation="Copy Number Alteration" toProperty="output_file" />
  <link fromOperation="input connector" fromProperty="bam_window_version" toOperation="Copy Number Alteration" toProperty="bam_window_version" />
  <link fromOperation="input connector" fromProperty="bam_window_params" toOperation="Copy Number Alteration" toProperty="bam_window_params" />

  <link fromOperation="input connector" fromProperty="tumor_bam_file" toOperation="Indelpe Runner Tumor" toProperty="bam_file" />
  <link fromOperation="input connector" fromProperty="reference_fasta" toOperation="Indelpe Runner Tumor" toProperty="ref_seq_file" />
  <link fromOperation="input connector" fromProperty="tumor_indelpe_data_directory" toOperation="Indelpe Runner Tumor" toProperty="output_dir" />
  <link fromOperation="input connector" fromProperty="tumor_snp_file" toOperation="Indelpe Runner Tumor" toProperty="filtered_snp_file" />
  <link fromOperation="input connector" fromProperty="skip_tumor_indelpe" toOperation="Indelpe Runner Tumor" toProperty="skip" />

  <link fromOperation="input connector" fromProperty="normal_bam_file" toOperation="Indelpe Runner Normal" toProperty="bam_file" />
  <link fromOperation="input connector" fromProperty="reference_fasta" toOperation="Indelpe Runner Normal" toProperty="ref_seq_file" />
  <link fromOperation="input connector" fromProperty="normal_indelpe_data_directory" toOperation="Indelpe Runner Normal" toProperty="output_dir" />
  <link fromOperation="input connector" fromProperty="normal_snp_file" toOperation="Indelpe Runner Normal" toProperty="filtered_snp_file" />
  <link fromOperation="input connector" fromProperty="skip_normal_indelpe" toOperation="Indelpe Runner Normal" toProperty="skip" />

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Snp Filter" toProperty="skip_if_output_present" />
  <link fromOperation="Indelpe Runner Tumor" fromProperty="filtered_snp_file" toOperation="Snp Filter" toProperty="tumor_snp_file" />
  <link fromOperation="input connector" fromProperty="snp_filter_output" toOperation="Snp Filter" toProperty="output_file" />
  <link fromOperation="Somatic Sniper" fromProperty="snp_output" toOperation="Snp Filter" toProperty="sniper_snp_file" />

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Filter Loh" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="loh_output_file" toOperation="Filter Loh" toProperty="output_file" />
  <link fromOperation="input connector" fromProperty="loh_fail_output_file" toOperation="Filter Loh" toProperty="loh_output_file" />
  <link fromOperation="Indelpe Runner Normal" fromProperty="filtered_snp_file" toOperation="Filter Loh" toProperty="normal_snp_file" />
  <link fromOperation="Snp Filter" fromProperty="output_file" toOperation="Filter Loh" toProperty="tumor_snp_file" />

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Filter CEU YRI" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="filter_ceu_yri_output" toOperation="Filter CEU YRI" toProperty="output_file" />
  <link fromOperation="Filter Loh" fromProperty="output_file" toOperation="Filter CEU YRI" toProperty="variant_file" />

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Sniper Adaptor Snp" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="adaptor_output_snp" toOperation="Sniper Adaptor Snp" toProperty="output_file" />
  <link fromOperation="Filter CEU YRI" fromProperty="output_file" toOperation="Sniper Adaptor Snp" toProperty="somatic_file" />

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Lookup Variants" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="dbsnp_output" toOperation="Lookup Variants" toProperty="output_file" />
  <link fromOperation="Sniper Adaptor Snp" fromProperty="output_file" toOperation="Lookup Variants" toProperty="variant_file" />
  <link fromOperation="input connector" fromProperty="lookup_variants_report_mode" toOperation="Lookup Variants" toProperty="report_mode" />
  <link fromOperation="input connector" fromProperty="lookup_variants_filter_out_submitters" toOperation="Lookup Variants" toProperty="filter_out_submitters" />
  <link fromOperation="input connector" fromProperty="require_dbsnp_allele_match" toOperation="Lookup Variants" toProperty="require_allele_match" />
  
  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Annotate Transcript Variants Snp" toProperty="skip_if_output_present" />
  <link fromOperation="Lookup Variants" fromProperty="output_file" toOperation="Annotate Transcript Variants Snp" toProperty="variant_file" />
  <link fromOperation="input connector" fromProperty="annotate_output_snp" toOperation="Annotate Transcript Variants Snp" toProperty="output_file" />
  <link fromOperation="input connector" fromProperty="annotate_no_headers" toOperation="Annotate Transcript Variants Snp" toProperty="no_headers" />
  <link fromOperation="input connector" fromProperty="transcript_annotation_filter" toOperation="Annotate Transcript Variants Snp" toProperty="annotation_filter" />

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Annotate UCSC Snp" toProperty="skip_if_output_present" />
  <link fromOperation="Lookup Variants" fromProperty="output_file" toOperation="Annotate UCSC Snp" toProperty="input_file" />
  <link fromOperation="input connector" fromProperty="ucsc_output_snp" toOperation="Annotate UCSC Snp" toProperty="output_file" /> 
  <link fromOperation="input connector" fromProperty="ucsc_unannotated_output_snp" toOperation="Annotate UCSC Snp" toProperty="unannotated_file" /> 
  <link fromOperation="input connector" fromProperty="only_tier_1" toOperation="Annotate UCSC Snp" toProperty="skip" /> 
    
  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Tier Variants Snp" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="tier_1_snp_file" toOperation="Tier Variants Snp" toProperty="tier1_file" />
  <link fromOperation="input connector" fromProperty="tier_2_snp_file" toOperation="Tier Variants Snp" toProperty="tier2_file" />
  <link fromOperation="input connector" fromProperty="tier_3_snp_file" toOperation="Tier Variants Snp" toProperty="tier3_file" />
  <link fromOperation="input connector" fromProperty="tier_4_snp_file" toOperation="Tier Variants Snp" toProperty="tier4_file" />
  <link fromOperation="input connector" fromProperty="only_tier_1" toOperation="Tier Variants Snp" toProperty="only_tier_1" />
  <link fromOperation="Annotate UCSC Snp" fromProperty="output_file" toOperation="Tier Variants Snp" toProperty="ucsc_file" />
  <link fromOperation="Lookup Variants" fromProperty="output_file" toOperation="Tier Variants Snp" toProperty="variant_file" />
  <link fromOperation="Annotate Transcript Variants Snp" fromProperty="output_file" toOperation="Tier Variants Snp" toProperty="transcript_annotation_file" />

  <link fromOperation="input connector" fromProperty="imported_bams" toOperation="High Confidence Snp Tier 1" toProperty="prepend_chr" />
  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="High Confidence Snp Tier 1" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="min_mapping_quality" toOperation="High Confidence Snp Tier 1" toProperty="min_mapping_quality" />
  <link fromOperation="input connector" fromProperty="min_somatic_quality" toOperation="High Confidence Snp Tier 1" toProperty="min_somatic_quality" />
  <link fromOperation="input connector" fromProperty="tumor_bam_file" toOperation="High Confidence Snp Tier 1" toProperty="tumor_bam_file" />
  <link fromOperation="input connector" fromProperty="tier_1_snp_high_confidence_file" toOperation="High Confidence Snp Tier 1" toProperty="output_file" />
  <link fromOperation="Tier Variants Snp" fromProperty="tier1_file" toOperation="High Confidence Snp Tier 1" toProperty="sniper_file" />
  <link fromOperation="input connector" fromProperty="bam_readcount_version" toOperation="High Confidence Snp Tier 1" toProperty="bam_readcount_version" />
  <link fromOperation="input connector" fromProperty="bam_readcount_params" toOperation="High Confidence Snp Tier 1" toProperty="bam_readcount_params" />

  <link fromOperation="input connector" fromProperty="imported_bams" toOperation="High Confidence Snp Tier 2" toProperty="prepend_chr" />
  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="High Confidence Snp Tier 2" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="min_mapping_quality" toOperation="High Confidence Snp Tier 2" toProperty="min_mapping_quality" />
  <link fromOperation="input connector" fromProperty="min_somatic_quality" toOperation="High Confidence Snp Tier 2" toProperty="min_somatic_quality" />
  <link fromOperation="input connector" fromProperty="tumor_bam_file" toOperation="High Confidence Snp Tier 2" toProperty="tumor_bam_file" />
  <link fromOperation="input connector" fromProperty="tier_2_snp_high_confidence_file" toOperation="High Confidence Snp Tier 2" toProperty="output_file" />
  <link fromOperation="input connector" fromProperty="only_tier_1" toOperation="High Confidence Snp Tier 2" toProperty="skip" /> 
  <link fromOperation="Tier Variants Snp" fromProperty="tier2_file" toOperation="High Confidence Snp Tier 2" toProperty="sniper_file" />
  <link fromOperation="input connector" fromProperty="bam_readcount_version" toOperation="High Confidence Snp Tier 2" toProperty="bam_readcount_version" />
  <link fromOperation="input connector" fromProperty="bam_readcount_params" toOperation="High Confidence Snp Tier 2" toProperty="bam_readcount_params" />

  <link fromOperation="input connector" fromProperty="imported_bams" toOperation="High Confidence Snp Tier 3" toProperty="prepend_chr" />
  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="High Confidence Snp Tier 3" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="min_mapping_quality" toOperation="High Confidence Snp Tier 3" toProperty="min_mapping_quality" />
  <link fromOperation="input connector" fromProperty="min_somatic_quality" toOperation="High Confidence Snp Tier 3" toProperty="min_somatic_quality" />
  <link fromOperation="input connector" fromProperty="tumor_bam_file" toOperation="High Confidence Snp Tier 3" toProperty="tumor_bam_file" />
  <link fromOperation="input connector" fromProperty="tier_3_snp_high_confidence_file" toOperation="High Confidence Snp Tier 3" toProperty="output_file" />
  <link fromOperation="input connector" fromProperty="only_tier_1" toOperation="High Confidence Snp Tier 3" toProperty="skip" /> 
  <link fromOperation="Tier Variants Snp" fromProperty="tier3_file" toOperation="High Confidence Snp Tier 3" toProperty="sniper_file" />
  <link fromOperation="input connector" fromProperty="bam_readcount_version" toOperation="High Confidence Snp Tier 3" toProperty="bam_readcount_version" />
  <link fromOperation="input connector" fromProperty="bam_readcount_params" toOperation="High Confidence Snp Tier 3" toProperty="bam_readcount_params" />

  <link fromOperation="input connector" fromProperty="imported_bams" toOperation="High Confidence Snp Tier 4" toProperty="prepend_chr" />
  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="High Confidence Snp Tier 4" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="min_mapping_quality" toOperation="High Confidence Snp Tier 4" toProperty="min_mapping_quality" />
  <link fromOperation="input connector" fromProperty="min_somatic_quality" toOperation="High Confidence Snp Tier 4" toProperty="min_somatic_quality" />
  <link fromOperation="input connector" fromProperty="tumor_bam_file" toOperation="High Confidence Snp Tier 4" toProperty="tumor_bam_file" />
  <link fromOperation="input connector" fromProperty="tier_4_snp_high_confidence_file" toOperation="High Confidence Snp Tier 4" toProperty="output_file" />
  <link fromOperation="input connector" fromProperty="only_tier_1" toOperation="High Confidence Snp Tier 4" toProperty="skip" /> 
  <link fromOperation="Tier Variants Snp" fromProperty="tier4_file" toOperation="High Confidence Snp Tier 4" toProperty="sniper_file" />
  <link fromOperation="input connector" fromProperty="bam_readcount_version" toOperation="High Confidence Snp Tier 4" toProperty="bam_readcount_version" />
  <link fromOperation="input connector" fromProperty="bam_readcount_params" toOperation="High Confidence Snp Tier 4" toProperty="bam_readcount_params" />

  <link fromOperation="High Confidence Snp Tier 1" fromProperty="output_file" toOperation="Upload Variants Snp Tier 1" toProperty="variant_file" />
  <link fromOperation="Annotate Transcript Variants Snp" fromProperty="output_file" toOperation="Upload Variants Snp Tier 1" toProperty="annotation_file" />
  <link fromOperation="input connector" fromProperty="upload_variants_snp_1_output" toOperation="Upload Variants Snp Tier 1" toProperty="output_file" />
  <link fromOperation="input connector" fromProperty="build_id" toOperation="Upload Variants Snp Tier 1" toProperty="build_id" />

  <link fromOperation="High Confidence Snp Tier 2" fromProperty="output_file" toOperation="Upload Variants Snp Tier 2" toProperty="variant_file" />
  <link fromOperation="Annotate Transcript Variants Snp" fromProperty="output_file" toOperation="Upload Variants Snp Tier 2" toProperty="annotation_file" />
  <link fromOperation="input connector" fromProperty="upload_variants_snp_2_output" toOperation="Upload Variants Snp Tier 2" toProperty="output_file" />
  <link fromOperation="input connector" fromProperty="build_id" toOperation="Upload Variants Snp Tier 2" toProperty="build_id" />
  <link fromOperation="input connector" fromProperty="only_tier_1" toOperation="Upload Variants Snp Tier 2" toProperty="_skip" />

  <link fromOperation="Upload Variants Snp Tier 1" fromProperty="output_file" toOperation="output connector" toProperty="tier_1_snp_high_confidence" />
  <link fromOperation="Upload Variants Snp Tier 2" fromProperty="output_file" toOperation="output connector" toProperty="tier_2_snp_high_confidence" />

  <link fromOperation="High Confidence Snp Tier 3" fromProperty="output_file" toOperation="output connector" toProperty="tier_3_snp_high_confidence" />
  <link fromOperation="High Confidence Snp Tier 4" fromProperty="output_file" toOperation="output connector" toProperty="tier_4_snp_high_confidence" />

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Library Support Filter" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="indel_lib_filter_preferred_output" toOperation="Library Support Filter" toProperty="preferred_output_file" />
  <link fromOperation="input connector" fromProperty="indel_lib_filter_single_output" toOperation="Library Support Filter" toProperty="single_lib_output_file" />
  <link fromOperation="input connector" fromProperty="indel_lib_filter_multi_output" toOperation="Library Support Filter" toProperty="multi_lib_output_file" />
  <link fromOperation="Somatic Sniper" fromProperty="indel_output" toOperation="Library Support Filter" toProperty="indel_file" />

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Sniper Adaptor Indel" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="adaptor_output_indel" toOperation="Sniper Adaptor Indel" toProperty="output_file" />
  <link fromOperation="Library Support Filter" fromProperty="preferred_output_file" toOperation="Sniper Adaptor Indel" toProperty="somatic_file" />

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Annotate Transcript Variants Indel" toProperty="skip_if_output_present" />
  <link fromOperation="Sniper Adaptor Indel" fromProperty="output_file" toOperation="Annotate Transcript Variants Indel" toProperty="variant_file" />
  <link fromOperation="input connector" fromProperty="annotate_output_indel" toOperation="Annotate Transcript Variants Indel" toProperty="output_file" />
  <link fromOperation="input connector" fromProperty="annotate_no_headers" toOperation="Annotate Transcript Variants Indel" toProperty="no_headers" />
  <link fromOperation="input connector" fromProperty="transcript_annotation_filter" toOperation="Annotate Transcript Variants Indel" toProperty="annotation_filter" />

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Annotate UCSC Indel" toProperty="skip_if_output_present" />
  <link fromOperation="Sniper Adaptor Indel" fromProperty="output_file" toOperation="Annotate UCSC Indel" toProperty="input_file" />
  <link fromOperation="input connector" fromProperty="ucsc_output_indel" toOperation="Annotate UCSC Indel" toProperty="output_file" /> 
  <link fromOperation="input connector" fromProperty="ucsc_unannotated_output_indel" toOperation="Annotate UCSC Indel" toProperty="unannotated_file" /> 
  <link fromOperation="input connector" fromProperty="only_tier_1" toOperation="Annotate UCSC Indel" toProperty="skip" /> 

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Tier Variants Indel" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="tier_1_indel_file" toOperation="Tier Variants Indel" toProperty="tier1_file" />
  <link fromOperation="input connector" fromProperty="tier_2_indel_file" toOperation="Tier Variants Indel" toProperty="tier2_file" />
  <link fromOperation="input connector" fromProperty="tier_3_indel_file" toOperation="Tier Variants Indel" toProperty="tier3_file" />
  <link fromOperation="input connector" fromProperty="tier_4_indel_file" toOperation="Tier Variants Indel" toProperty="tier4_file" />
  <link fromOperation="input connector" fromProperty="only_tier_1" toOperation="Tier Variants Indel" toProperty="only_tier_1" />
  <link fromOperation="Annotate UCSC Indel" fromProperty="output_file" toOperation="Tier Variants Indel" toProperty="ucsc_file" />
  <link fromOperation="Sniper Adaptor Indel" fromProperty="output_file" toOperation="Tier Variants Indel" toProperty="variant_file" />
  <link fromOperation="Annotate Transcript Variants Indel" fromProperty="output_file" toOperation="Tier Variants Indel" toProperty="transcript_annotation_file" />

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Plot Circos" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="circos_graph" toOperation="Plot Circos" toProperty="output_file" />
  <link fromOperation="Copy Number Alteration" fromProperty="output_file" toOperation="Plot Circos" toProperty="cna_file" />
  <link fromOperation="Breakdancer" fromProperty="sv_output" toOperation="Plot Circos" toProperty="sv_file" />
  <link fromOperation="Upload Variants Snp Tier 1" fromProperty="output_file" toOperation="Plot Circos" toProperty="tier1_hclabel_file" />

  <link fromOperation="Tier Variants Indel" fromProperty="tier1_file" toOperation="Upload Variants Indel Tier 1" toProperty="variant_file" />
  <link fromOperation="Annotate Transcript Variants Indel" fromProperty="output_file" toOperation="Upload Variants Indel Tier 1" toProperty="annotation_file" />
  <link fromOperation="input connector" fromProperty="upload_variants_indel_1_output" toOperation="Upload Variants Indel Tier 1" toProperty="output_file" />
  <link fromOperation="input connector" fromProperty="build_id" toOperation="Upload Variants Indel Tier 1" toProperty="build_id" />

  <link fromOperation="Tier Variants Indel" fromProperty="tier2_file" toOperation="Upload Variants Indel Tier 2" toProperty="variant_file" />
  <link fromOperation="Annotate Transcript Variants Indel" fromProperty="output_file" toOperation="Upload Variants Indel Tier 2" toProperty="annotation_file" />
  <link fromOperation="input connector" fromProperty="upload_variants_indel_2_output" toOperation="Upload Variants Indel Tier 2" toProperty="output_file" />
  <link fromOperation="input connector" fromProperty="build_id" toOperation="Upload Variants Indel Tier 2" toProperty="build_id" />
  <link fromOperation="input connector" fromProperty="only_tier_1" toOperation="Upload Variants Indel Tier 2" toProperty="_skip" />

  <link fromOperation="input connector" fromProperty="build_id" toOperation="Wait for Database Upload" toProperty="build_id" />
  <link fromOperation="Upload Variants Indel Tier 1" fromProperty="result" toOperation="Wait for Database Upload" toProperty="upload indel result" />
  <link fromOperation="Upload Variants Snp Tier 2" fromProperty="result" toOperation="Wait for Database Upload" toProperty="upload snp tier 2 result" />
  <link fromOperation="Plot Circos" fromProperty="result" toOperation="Wait for Database Upload" toProperty="plot circos result" />

  <link fromOperation="Wait for Database Upload" fromProperty="build_id" toOperation="Generate Reports" toProperty="build_id" />
  <link fromOperation="input connector" fromProperty="variant_report_output" toOperation="Generate Reports" toProperty="variant_report_output" />
  <link fromOperation="input connector" fromProperty="file_summary_report_output" toOperation="Generate Reports" toProperty="file_summary_report_output" />
  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Generate Reports" toProperty="skip_if_output_present" />

  <link fromOperation="Plot Circos" fromProperty="output_file" toOperation="output connector" toProperty="circos_big_graph" />
  <link fromOperation="Upload Variants Indel Tier 1" fromProperty="output_file" toOperation="output connector" toProperty="tier_1_indel_output" />
  <link fromOperation="Upload Variants Indel Tier 2" fromProperty="output_file" toOperation="output connector" toProperty="tier_2_indel_output" />
  <link fromOperation="Generate Reports" fromProperty="variant_report_output" toOperation="output connector" toProperty="final_variant_report_output" />
  

  <operation name="Somatic Sniper">
    <operationtype commandClass="Genome::Model::Tools::DetectVariants::Somatic::Sniper" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operation name="Breakdancer">
    <operationtype commandClass="Genome::Model::Tools::DetectVariants::Somatic::Breakdancer" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operation name="Copy Number Alteration">
    <operationtype commandClass="Genome::Model::Tools::Somatic::BamToCna" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operation name="Indelpe Runner Tumor">
    <operationtype commandClass="Genome::Model::Tools::Somatic::IndelpeRunner" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operation name="Indelpe Runner Normal">
    <operationtype commandClass="Genome::Model::Tools::Somatic::IndelpeRunner" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operation name="Snp Filter">
    <operationtype commandClass="Genome::Model::Tools::Somatic::SnpFilter" typeClass="Workflow::OperationType::Command" />
  </operation>
  <operation name="Filter CEU YRI">
      <operationtype commandClass="Genome::Model::Tools::Somatic::FilterCeuYri" typeClass="Workflow::OperationType::Command" />
  </operation>   
  <operation name="Sniper Adaptor Snp">
    <operationtype commandClass="Genome::Model::Tools::Annotate::Adaptor::Sniper" typeClass="Workflow::OperationType::Command" />
  </operation>
  <operation name="Lookup Variants">
      <operationtype commandClass="Genome::Model::Tools::Annotate::LookupVariants" typeClass="Workflow::OperationType::Command" />
  </operation>   
  <operation name="Filter Loh">
      <operationtype commandClass="Genome::Model::Tools::Somatic::FilterLoh" typeClass="Workflow::OperationType::Command" />
  </operation>   
  <operation name="Annotate UCSC Snp">
      <operationtype commandClass="Genome::Model::Tools::Somatic::UcscAnnotator" typeClass="Workflow::OperationType::Command" />
  </operation>
  <operation name="Annotate Transcript Variants Snp">
    <operationtype commandClass="Genome::Model::Tools::Annotate::TranscriptVariants" typeClass="Workflow::OperationType::Command" />
  </operation>
  <operation name="Tier Variants Snp">
    <operationtype commandClass="Genome::Model::Tools::Somatic::TierVariants" typeClass="Workflow::OperationType::Command" />
  </operation>
  <operation name="High Confidence Snp Tier 1">
    <operationtype commandClass="Genome::Model::Tools::Somatic::HighConfidence" typeClass="Workflow::OperationType::Command" />
  </operation>
  <operation name="High Confidence Snp Tier 2">
    <operationtype commandClass="Genome::Model::Tools::Somatic::HighConfidence" typeClass="Workflow::OperationType::Command" />
  </operation>
  <operation name="High Confidence Snp Tier 3">
    <operationtype commandClass="Genome::Model::Tools::Somatic::HighConfidence" typeClass="Workflow::OperationType::Command" />
  </operation>
  <operation name="High Confidence Snp Tier 4">
    <operationtype commandClass="Genome::Model::Tools::Somatic::HighConfidence" typeClass="Workflow::OperationType::Command" />
  </operation>
  <operation name="Upload Variants Snp Tier 1">
    <operationtype commandClass="Genome::Model::Tools::Somatic::UploadVariants" typeClass="Workflow::OperationType::Command" />
  </operation>
  <operation name="Upload Variants Snp Tier 2">
    <operationtype commandClass="Genome::Model::Tools::Somatic::UploadVariants" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operation name="Library Support Filter">
    <operationtype commandClass="Genome::Model::Tools::Somatic::LibrarySupportFilter" typeClass="Workflow::OperationType::Command" />
  </operation>
  <operation name="Sniper Adaptor Indel">
    <operationtype commandClass="Genome::Model::Tools::Annotate::Adaptor::Sniper" typeClass="Workflow::OperationType::Command" />
  </operation>
  <operation name="Annotate Transcript Variants Indel">
    <operationtype commandClass="Genome::Model::Tools::Annotate::TranscriptVariants" typeClass="Workflow::OperationType::Command" />
  </operation>
  <operation name="Annotate UCSC Indel">
      <operationtype commandClass="Genome::Model::Tools::Somatic::UcscAnnotator" typeClass="Workflow::OperationType::Command" />
  </operation>
  <operation name="Tier Variants Indel">
    <operationtype commandClass="Genome::Model::Tools::Somatic::TierVariants" typeClass="Workflow::OperationType::Command" />
  </operation>
  <operation name="Upload Variants Indel Tier 1">
    <operationtype commandClass="Genome::Model::Tools::Somatic::UploadVariants" typeClass="Workflow::OperationType::Command" />
  </operation>
  <operation name="Upload Variants Indel Tier 2">
    <operationtype commandClass="Genome::Model::Tools::Somatic::UploadVariants" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operation name="Plot Circos">
    <operationtype commandClass="Genome::Model::Tools::Somatic::PlotCircos" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operation name="Wait for Database Upload">
      <operationtype typeClass="Workflow::OperationType::Block">
        <property>build_id</property>
        <property>upload snp tier 2 result</property>
        <property>upload indel result</property>
        <property>plot circos result</property>
    </operationtype>
  </operation>

  <operation name="Generate Reports">
    <operationtype commandClass="Genome::Model::Tools::Somatic::RunReports" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operationtype typeClass="Workflow::OperationType::Model">
    <inputproperty>normal_bam_file</inputproperty>
    <inputproperty>tumor_bam_file</inputproperty>
    <inputproperty>build_id</inputproperty>
    <inputproperty isOptional="Y">skip_if_output_present</inputproperty>
    <inputproperty isOptional="Y">tumor_snp_file</inputproperty>
    <inputproperty isOptional="Y">normal_snp_file</inputproperty>
    <inputproperty isOptional="Y">reference_fasta</inputproperty>
    <inputproperty isOptional="Y">imported_bams</inputproperty>
    <inputproperty isOptional="Y">breakdancer_params</inputproperty>
    <inputproperty isOptional="Y">bam2cfg_params</inputproperty>
    <inputproperty isOptional="Y">sv_params</inputproperty>
    <inputproperty isOptional="Y">breakdancer_version</inputproperty>
    <inputproperty isOptional="Y">skip_tumor_indelpe</inputproperty>
    <inputproperty isOptional="Y">skip_normal_indelpe</inputproperty>
    <inputproperty>sniper_version</inputproperty>
    <inputproperty>sniper_params</inputproperty>
    <inputproperty>bam_window_version</inputproperty>
    <inputproperty>bam_window_params</inputproperty>
    <inputproperty>bam_readcount_version</inputproperty>
    <inputproperty>bam_readcount_params</inputproperty>

    <inputproperty isOptional="Y">sniper_working_directory</inputproperty>

    <inputproperty isOptional="Y">only_tier_1</inputproperty>
    <inputproperty isOptional="Y">skip_sv</inputproperty>

    <inputproperty isOptional="Y">data_directory</inputproperty>

    <inputproperty isOptional="Y">breakdancer_working_directory</inputproperty>
    
    <inputproperty isOptional="Y">copy_number_output</inputproperty>

    <inputproperty isOptional="Y">normal_indelpe_data_directory</inputproperty>
    <inputproperty isOptional="Y">tumor_indelpe_data_directory</inputproperty>

    <inputproperty isOptional="Y">snp_filter_output</inputproperty>
    
    <inputproperty isOptional="Y">filter_ceu_yri_output</inputproperty>
            
    <inputproperty isOptional="Y">adaptor_output_snp</inputproperty>

    <inputproperty isOptional="Y">dbsnp_output</inputproperty>
    <inputproperty isOptional="Y">lookup_variants_report_mode</inputproperty>
    <inputproperty isOptional="Y">lookup_variants_filter_out_submitters</inputproperty>
    <inputproperty isOptional="Y">require_dbsnp_allele_match</inputproperty>

    <inputproperty isOptional="Y">loh_output_file</inputproperty>
    <inputproperty isOptional="Y">loh_fail_output_file</inputproperty>

    <inputproperty isOptional="Y">annotate_output_snp</inputproperty>
    <inputproperty isOptional="Y">annotate_no_headers</inputproperty>
    <inputproperty isOptional="Y">transcript_annotation_filter</inputproperty>
    
    <inputproperty isOptional="Y">ucsc_output_snp</inputproperty>
    <inputproperty isOptional="Y">ucsc_unannotated_output_snp</inputproperty>
    <inputproperty isOptional="Y">ucsc_output_indel</inputproperty>
    <inputproperty isOptional="Y">ucsc_unannotated_output_indel</inputproperty>

    <inputproperty isOptional="Y">tier_1_snp_file</inputproperty>
    <inputproperty isOptional="Y">tier_2_snp_file</inputproperty>
    <inputproperty isOptional="Y">tier_3_snp_file</inputproperty>
    <inputproperty isOptional="Y">tier_4_snp_file</inputproperty>

    <inputproperty isOptional="Y">min_mapping_quality</inputproperty>
    <inputproperty isOptional="Y">min_somatic_quality</inputproperty>
    <inputproperty isOptional="Y">tier_1_snp_high_confidence_file</inputproperty>
    <inputproperty isOptional="Y">tier_2_snp_high_confidence_file</inputproperty>
    <inputproperty isOptional="Y">tier_3_snp_high_confidence_file</inputproperty>
    <inputproperty isOptional="Y">tier_4_snp_high_confidence_file</inputproperty>

    <inputproperty isOptional="Y">upload_variants_snp_1_output</inputproperty>
    <inputproperty isOptional="Y">upload_variants_snp_2_output</inputproperty>
    <inputproperty isOptional="Y">upload_variants_indel_1_output</inputproperty>
    <inputproperty isOptional="Y">upload_variants_indel_2_output</inputproperty>
    
    <inputproperty isOptional="Y">tier_1_indel_file</inputproperty>
    <inputproperty isOptional="Y">tier_2_indel_file</inputproperty>
    <inputproperty isOptional="Y">tier_3_indel_file</inputproperty>
    <inputproperty isOptional="Y">tier_4_indel_file</inputproperty>

    <outputproperty>tier_1_snp_high_confidence</outputproperty>
    <outputproperty>tier_2_snp_high_confidence</outputproperty>
    <outputproperty>tier_3_snp_high_confidence</outputproperty>
    <outputproperty>tier_4_snp_high_confidence</outputproperty>

    <inputproperty isOptional="Y">indel_lib_filter_preferred_output</inputproperty>
    <inputproperty isOptional="Y">indel_lib_filter_single_output</inputproperty>
    <inputproperty isOptional="Y">indel_lib_filter_multi_output</inputproperty>
    <inputproperty isOptional="Y">adaptor_output_indel</inputproperty>
    <inputproperty isOptional="Y">annotate_output_indel</inputproperty>

    <inputproperty isOptional="Y">circos_graph</inputproperty>

    <inputproperty isOptional="Y">variant_report_output</inputproperty>
    <inputproperty isOptional="Y">file_summary_report_output</inputproperty>

    <outputproperty>tier_1_indel_output</outputproperty>
    <outputproperty>tier_2_indel_output</outputproperty>
    <outputproperty>circos_big_graph</outputproperty>
    <outputproperty>final_variant_report_output</outputproperty>
  </operationtype>

</workflow>


