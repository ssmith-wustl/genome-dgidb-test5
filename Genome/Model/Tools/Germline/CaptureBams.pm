package Genome::Model::Tools::Germline::CaptureBams;

########################################################################################################################
# CaptureBams.pm - A module for comparing tumor-normal BAM files in capture data
#
#   TO-DO LIST
#   -Merge somaticSniper and VarScan somatic calls
#   -Merge somaticSniper and VarScan germline calls
#   -Merge somaticSniper and VarScan LOH calls
#   -Format merged files for annotation
#   -Move CEU/YRI/dbSNP filters to AFTER annotation step
#   -Generate new endpoint files in MAF-like format
#   -Restrict endpoint variant calls to ROI ()
#   -Run Sample QC checks (SNP and CNV)
#   
########################################################################################################################

use strict;
use warnings;

class Genome::Model::Tools::Germline::CaptureBams {
    is => ['Workflow::Operation::Command'],
    workflow => sub { Workflow::Operation->create_from_xml(\*DATA); }
};

sub help_brief {
    "Runs the **capture** somatic pipeline workflow."
}

sub help_synopsis{
    my $self = shift;
    return <<"EOS"
gmt somatic compare capture-bams --normal-bam-file normal.bam --tumor-bam-file tumor.bam --tumor-snp-file tumor.snp --data-directory /some/dir/for/data
EOS
}

sub help_detail {
    my $self = shift;
    return <<"EOS"
This tool runs the capture somatic pipeline to compare a tumor and a normal for variant detection, structural variation detection, etc.
This tool is called automatically when running a build on a somatic-capture model.  See also 'genome model build somatic-capture'.
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
                #$self->status_message("Param $param was not provided... generated $default_filename as a default");
                $self->$param($self->data_directory . "/$default_filename");
            }
        }
    }

    # Set (hardcoded) defaults for tools that have defaults that do not agree with somatic pipeline
    unless (defined $self->skip_if_output_present) {
        $self->skip_if_output_present(1);
    }
    unless (defined $self->lookup_variants_report_mode) {
        $self->lookup_variants_report_mode("novel-only");
    }
    # Submitters to exclude from somatic pipeline as per dlarson. These guys submit cancer samples to dbsnp, or somesuch
    unless (defined $self->lookup_variants_filter_out_submitters) {
        $self->lookup_variants_filter_out_submitters("SNP500CANCER,OMIMSNP,CANCER-GENOME,CGAP-GAI,LCEISEN,ICRCG");
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
    unless (defined $self->only_tier_1_indel) {
        $self->only_tier_1_indel(1);
    }

    unless (defined $self->skip_sv) {
        $self->skip_sv(0);
    }

    # The output files of indel pe step should go into the workflow directory
    unless (defined $self->normal_indelpe_data_directory) {
        $self->normal_indelpe_data_directory($self->data_directory . "/normal_indelpe_data");
    }
    unless (defined $self->tumor_indelpe_data_directory) {
        $self->tumor_indelpe_data_directory($self->data_directory . "/tumor_indelpe_data");
    }
    # Default ref seq
    unless (defined $self->reference_fasta) {
        $self->reference_fasta("/gscmnt/839/info/medseq/reference_sequences/NCBI-human-build36/all_sequences.fa");
    }

    # Default high confidence parameters 
    unless (defined $self->min_mapping_quality) {
        $self->min_mapping_quality(70);
    }
    unless (defined $self->min_somatic_quality) {
        $self->min_somatic_quality(40);
    }

    return 1;
}

sub default_filenames{
    my $self = shift;
   
    my %default_filenames = (
        breakdancer_output_file             => 'breakdancer.out',
        breakdancer_config_file             => 'breakdancer.config',
        copy_number_output                  => 'copy_number.out',

        ## glfSomatic Output Files ##
        sniper_snp_output                   => 'somaticSniper.output.snp',
        snp_filter_output                   => 'somaticSniper.output.snp.filter',
        sniper_indel_output                 => 'somaticSniper.output.indel',
        indel_lib_filter_preferred_output   => 'somaticSniper.output.indel.filter.preferred',
        indel_lib_filter_single_output      => 'somaticSniper.output.indel.filter.single',
        indel_lib_filter_multi_output       => 'somaticSniper.output.indel.filter.multi',
        indel_capture_filter_output         => 'somaticSniper.output.indel.filter.capture',
        loh_output_file                     => 'somaticSniper.output.loh',
        loh_fail_output_file                => 'somaticSniper.output.loh.fail',

        ## VarScan Output Files ##
        varscan_snp_output                  => 'varScan.output.snp',
        varscan_indel_output                => 'varScan.output.indel',

        varscan_adaptor_snp                 => 'varScan.output.snp.formatted',
        varscan_adaptor_indel               => 'varScan.output.indel.formatted',
        
        varscan_snp_germline                => 'varScan.output.snp.formatted.Germline',
        varscan_snp_loh                     => 'varScan.output.snp.formatted.LOH',
        varscan_snp_somatic                 => 'varScan.output.snp.formatted.Somatic',
       
        varscan_indel_germline              => 'varScan.output.indel.formatted.Germline',
        varscan_indel_loh                   => 'varScan.output.indel.formatted.LOH',
        varscan_indel_somatic               => 'varScan.output.indel.formatted.Somatic',
        
        ## Combined glfSomatic+VarScan Output files ##
        merged_snp_output                   => 'merged.somatic.snp',            ## Generated from merge-variants of somaticSniper and varScan
        merged_snp_output_varscan           => 'merged.somatic.snp.varscan-only',            ## Generated from merge-variants of somaticSniper and varScan
        merged_snp_output_glf               => 'merged.somatic.snp.glf-only',            ## Generated from merge-variants of somaticSniper and varScan
        merged_snp_output_shared            => 'merged.somatic.snp.shared',            ## Generated from merge-variants of somaticSniper and varScan
        merged_snp_filter                   => 'merged.somatic.snp.filter',     ## Generated from somatic-snp-filter of merged_snp_output
        merged_indel_output                 => 'merged.somatic.indel',          ## Generated from merge-variants of somaticSniper and varScan ##

        merged_germline_snp                 => 'merged.germline.snp',           ## Generated from merge-variants of somaticSniper and varScan
        merged_loh_snp                      => 'merged.loh.snp',                ## Generated from merge-variants of somaticSniper and varScan

        ## Files formatted for annotation ##
        adaptor_output_snp                  => 'somaticSniper.output.snp.formatted',
        adaptor_output_indel                => 'somaticSniper.output.indel.formatted',
        
        ## Annotation output files ##
        annotate_output_snp                 => 'annotation.somatic.snp.transcript',
        ucsc_output                         => 'annotation.somatic.snp.ucsc',
        ucsc_unannotated_output             => 'annotation.somatic.snp.unannot-ucsc',
        annotate_output_indel               => 'annotation.somatic.indel.transcript',

        ## New annotation files for germline variants ##
        annotate_output_germline_snp        => 'annotation.germline.snp.transcript',
        annotate_output_germline_indel      => 'annotation.germline.indel.transcript',

        ## Filtering files for 1000 Genomes CEU/YRI and dbSNP ##
        filter_ceu_yri_output               => 'filter.ceu_yri.out',
        dbsnp_output                        => 'filter.dbsnp.out',

        ## Tiered SNP and indel files (all confidence) ##
        tier_1_snp_file                     => 'merged.somatic.snp.tier1.out',
        tier_2_snp_file                     => 'merged.somatic.snp.tier2.out',
        tier_3_snp_file                     => 'merged.somatic.snp.tier3.out',
        tier_4_snp_file                     => 'merged.somatic.snp.tier4.out',
        tier_1_indel_file                   => 'merged.somatic.indel.tier1.out',

        ## New Germline Files ##
        tier_1_germline_snp_file            => 'merged.germline.snp.tier1.out',
        tier_1_germline_indel_file            => 'merged.germline.indel.tier1.out',

        ## High-confidence tiered SNP and indel files ##
        tier_1_snp_high_confidence_file     => 'merged.somatic.high-confidence.snp.tier1.out',
        tier_2_snp_high_confidence_file     => 'merged.somatic.high-confidence.snp.tier2.out',
        tier_3_snp_high_confidence_file     => 'merged.somatic.high-confidence.snp.tier3.out',
        tier_4_snp_high_confidence_file     => 'merged.somatic.high-confidence.snp.tier4.out',
        tier_1_indel_high_confidence_file   => 'merged.somatic.high-confidence.indel.tier1.out',

        ## Put in medium and low confidence placeholders ##

        ## Other pipeline output files ##
        upload_variants_snp_1_output        => 'upload-variants.snp_1.out',
        upload_variants_snp_2_output        => 'upload-variants.snp_2.out',
        upload_variants_indel_output        => 'upload-variants.indel.out',
        circos_graph                        => 'circos_graph.out',
        report_output                       => 'cancer_report.html',
    );

    return %default_filenames;
}

1;
__DATA__
<?xml version='1.0' standalone='yes'?>

<workflow name="Somatic Pipeline" logDir="/gsc/var/log/genome/somatic_capture_pipeline">

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Somatic Sniper" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="normal_bam_file" toOperation="Somatic Sniper" toProperty="normal_bam_file" />
  <link fromOperation="input connector" fromProperty="tumor_bam_file" toOperation="Somatic Sniper" toProperty="tumor_bam_file" />
  <link fromOperation="input connector" fromProperty="sniper_snp_output" toOperation="Somatic Sniper" toProperty="output_snp_file" />
  <link fromOperation="input connector" fromProperty="sniper_indel_output" toOperation="Somatic Sniper" toProperty="output_indel_file" />
  <link fromOperation="input connector" fromProperty="reference_fasta" toOperation="Somatic Sniper" toProperty="reference_file" />

  <link fromOperation="input connector" fromProperty="normal_bam_file" toOperation="Varscan Somatic" toProperty="normal_bam" />
  <link fromOperation="input connector" fromProperty="tumor_bam_file" toOperation="Varscan Somatic" toProperty="tumor_bam" />
  <link fromOperation="input connector" fromProperty="reference_fasta" toOperation="Varscan Somatic" toProperty="reference" />
  <link fromOperation="input connector" fromProperty="varscan_snp_output" toOperation="Varscan Somatic" toProperty="output_snp" />
  <link fromOperation="input connector" fromProperty="varscan_indel_output" toOperation="Varscan Somatic" toProperty="output_indel" />

  <link fromOperation="Varscan Somatic" fromProperty="output_snp" toOperation="Format Varscan Snvs" toProperty="variants_file" />
  <link fromOperation="input connector" fromProperty="varscan_adaptor_snp" toOperation="Format Varscan Snvs" toProperty="output_file" />

  <link fromOperation="Varscan Somatic" fromProperty="output_indel" toOperation="Format Varscan Indels" toProperty="variants_file" />
  <link fromOperation="input connector" fromProperty="varscan_adaptor_indel" toOperation="Format Varscan Indels" toProperty="output_file" />
  
  <link fromOperation="Format Varscan Snvs" fromProperty="output_file" toOperation="Varscan ProcessSomatic SNP" toProperty="status_file" />
  <link fromOperation="input connector" fromProperty="varscan_snp_somatic" toOperation="Varscan ProcessSomatic SNP" toProperty="somatic_out" />  

  <link fromOperation="Format Varscan Indels" fromProperty="output_file" toOperation="Varscan ProcessSomatic Indel" toProperty="status_file" />
  <link fromOperation="input connector" fromProperty="varscan_indel_somatic" toOperation="Varscan ProcessSomatic Indel" toProperty="somatic_out" />

  <link fromOperation="Merge SNPs" fromProperty="output_file" toOperation="output connector" toProperty="somatic_snp_merged" />
  <link fromOperation="Merge SNPs" fromProperty="output_unique1" toOperation="output connector" toProperty="somatic_snp_unique1" />
  <link fromOperation="Merge SNPs" fromProperty="output_unique2" toOperation="output connector" toProperty="somatic_snp_unique2" />
  <link fromOperation="Merge SNPs" fromProperty="output_shared" toOperation="output connector" toProperty="somatic_snp_shared" />
  <link fromOperation="Varscan ProcessSomatic Indel" fromProperty="somatic_out" toOperation="output connector" toProperty="somatic_indel" />

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Breakdancer" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="normal_bam_file" toOperation="Breakdancer" toProperty="normal_bam_file" />
  <link fromOperation="input connector" fromProperty="tumor_bam_file" toOperation="Breakdancer" toProperty="tumor_bam_file" />
  <link fromOperation="input connector" fromProperty="breakdancer_output_file" toOperation="Breakdancer" toProperty="breakdancer_output" />
  <link fromOperation="input connector" fromProperty="breakdancer_config_file" toOperation="Breakdancer" toProperty="config_output" />
  <link fromOperation="input connector" fromProperty="skip_sv" toOperation="Breakdancer" toProperty="skip" />

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Copy Number Alteration" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="normal_bam_file" toOperation="Copy Number Alteration" toProperty="normal_bam_file" />
  <link fromOperation="input connector" fromProperty="tumor_bam_file" toOperation="Copy Number Alteration" toProperty="tumor_bam_file" />
  <link fromOperation="input connector" fromProperty="copy_number_output" toOperation="Copy Number Alteration" toProperty="output_file" />

  <link fromOperation="input connector" fromProperty="tumor_bam_file" toOperation="Indelpe Runner Tumor" toProperty="bam_file" />
  <link fromOperation="input connector" fromProperty="reference_fasta" toOperation="Indelpe Runner Tumor" toProperty="ref_seq_file" />
  <link fromOperation="input connector" fromProperty="tumor_indelpe_data_directory" toOperation="Indelpe Runner Tumor" toProperty="output_dir" />
  <link fromOperation="input connector" fromProperty="tumor_snp_file" toOperation="Indelpe Runner Tumor" toProperty="filtered_snp_file" />

  <link fromOperation="input connector" fromProperty="normal_bam_file" toOperation="Indelpe Runner Normal" toProperty="bam_file" />
  <link fromOperation="input connector" fromProperty="reference_fasta" toOperation="Indelpe Runner Normal" toProperty="ref_seq_file" />
  <link fromOperation="input connector" fromProperty="normal_indelpe_data_directory" toOperation="Indelpe Runner Normal" toProperty="output_dir" />
  <link fromOperation="input connector" fromProperty="normal_snp_file" toOperation="Indelpe Runner Normal" toProperty="filtered_snp_file" />

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Snp Filter" toProperty="skip_if_output_present" />
  <link fromOperation="Indelpe Runner Tumor" fromProperty="filtered_snp_file" toOperation="Snp Filter" toProperty="tumor_snp_file" />
  <link fromOperation="input connector" fromProperty="snp_filter_output" toOperation="Snp Filter" toProperty="output_file" />
  <link fromOperation="Somatic Sniper" fromProperty="output_snp_file" toOperation="Snp Filter" toProperty="sniper_snp_file" />

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Sniper Adaptor Snp" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="adaptor_output_snp" toOperation="Sniper Adaptor Snp" toProperty="output_file" />
  <link fromOperation="Snp Filter" fromProperty="output_file" toOperation="Sniper Adaptor Snp" toProperty="somatic_file" />

  <link fromOperation="Varscan ProcessSomatic SNP" fromProperty="somatic_out" toOperation="Merge SNPs" toProperty="varscan_file" />
  <link fromOperation="Sniper Adaptor Snp" fromProperty="output_file" toOperation="Merge SNPs" toProperty="glf_file" />
  <link fromOperation="input connector" fromProperty="merged_snp_output" toOperation="Merge SNPs" toProperty="output_file" />
  <link fromOperation="input connector" fromProperty="merged_snp_output_varscan" toOperation="Merge SNPs" toProperty="output_unique1" />
  <link fromOperation="input connector" fromProperty="merged_snp_output_glf" toOperation="Merge SNPs" toProperty="output_unique2" />
  <link fromOperation="input connector" fromProperty="merged_snp_output_shared" toOperation="Merge SNPs" toProperty="output_shared" />
  
  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Annotate Transcript Variants Snp" toProperty="skip_if_output_present" />
  <link fromOperation="Merge SNPs" fromProperty="output_file" toOperation="Annotate Transcript Variants Snp" toProperty="variant_file" />
  <link fromOperation="input connector" fromProperty="annotate_output_snp" toOperation="Annotate Transcript Variants Snp" toProperty="output_file" />
  <link fromOperation="input connector" fromProperty="annotate_no_headers" toOperation="Annotate Transcript Variants Snp" toProperty="no_headers" />
  <link fromOperation="input connector" fromProperty="transcript_annotation_filter" toOperation="Annotate Transcript Variants Snp" toProperty="annotation_filter" />

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Annotate UCSC" toProperty="skip_if_output_present" />
  <link fromOperation="Merge SNPs" fromProperty="output_file" toOperation="Annotate UCSC" toProperty="input_file" />
  <link fromOperation="input connector" fromProperty="ucsc_output" toOperation="Annotate UCSC" toProperty="output_file" /> 
  <link fromOperation="input connector" fromProperty="ucsc_unannotated_output" toOperation="Annotate UCSC" toProperty="unannotated_file" /> 
  <link fromOperation="input connector" fromProperty="only_tier_1" toOperation="Annotate UCSC" toProperty="skip" /> 
    
  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Filter CEU YRI" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="filter_ceu_yri_output" toOperation="Filter CEU YRI" toProperty="output_file" />
  <link fromOperation="Merge SNPs" fromProperty="output_file" toOperation="Filter CEU YRI" toProperty="variant_file" />

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Lookup Variants" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="dbsnp_output" toOperation="Lookup Variants" toProperty="output_file" />
  <link fromOperation="Filter CEU YRI" fromProperty="output_file" toOperation="Lookup Variants" toProperty="variant_file" />
  <link fromOperation="input connector" fromProperty="lookup_variants_report_mode" toOperation="Lookup Variants" toProperty="report_mode" />
  <link fromOperation="input connector" fromProperty="lookup_variants_filter_out_submitters" toOperation="Lookup Variants" toProperty="filter_out_submitters" />

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Filter Loh" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="loh_output_file" toOperation="Filter Loh" toProperty="output_file" />
  <link fromOperation="input connector" fromProperty="loh_fail_output_file" toOperation="Filter Loh" toProperty="loh_output_file" />
  <link fromOperation="Indelpe Runner Normal" fromProperty="filtered_snp_file" toOperation="Filter Loh" toProperty="normal_snp_file" />
  <link fromOperation="Lookup Variants" fromProperty="output_file" toOperation="Filter Loh" toProperty="tumor_snp_file" />

    
  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Tier Variants Snp" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="tier_1_snp_file" toOperation="Tier Variants Snp" toProperty="tier1_file" />
  <link fromOperation="input connector" fromProperty="tier_2_snp_file" toOperation="Tier Variants Snp" toProperty="tier2_file" />
  <link fromOperation="input connector" fromProperty="tier_3_snp_file" toOperation="Tier Variants Snp" toProperty="tier3_file" />
  <link fromOperation="input connector" fromProperty="tier_4_snp_file" toOperation="Tier Variants Snp" toProperty="tier4_file" />
  <link fromOperation="input connector" fromProperty="only_tier_1" toOperation="Tier Variants Snp" toProperty="only_tier_1" />
  <link fromOperation="Annotate UCSC" fromProperty="output_file" toOperation="Tier Variants Snp" toProperty="ucsc_file" />
  <link fromOperation="Filter Loh" fromProperty="output_file" toOperation="Tier Variants Snp" toProperty="variant_file" />
  <link fromOperation="Annotate Transcript Variants Snp" fromProperty="output_file" toOperation="Tier Variants Snp" toProperty="transcript_annotation_file" />

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="High Confidence Snp Tier 1" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="min_mapping_quality" toOperation="High Confidence Snp Tier 1" toProperty="min_mapping_quality" />
  <link fromOperation="input connector" fromProperty="min_somatic_quality" toOperation="High Confidence Snp Tier 1" toProperty="min_somatic_quality" />
  <link fromOperation="input connector" fromProperty="tumor_bam_file" toOperation="High Confidence Snp Tier 1" toProperty="tumor_bam_file" />
  <link fromOperation="input connector" fromProperty="tier_1_snp_high_confidence_file" toOperation="High Confidence Snp Tier 1" toProperty="output_file" />
  <link fromOperation="Tier Variants Snp" fromProperty="tier1_file" toOperation="High Confidence Snp Tier 1" toProperty="sniper_file" />

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="High Confidence Snp Tier 2" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="min_mapping_quality" toOperation="High Confidence Snp Tier 2" toProperty="min_mapping_quality" />
  <link fromOperation="input connector" fromProperty="min_somatic_quality" toOperation="High Confidence Snp Tier 2" toProperty="min_somatic_quality" />
  <link fromOperation="input connector" fromProperty="tumor_bam_file" toOperation="High Confidence Snp Tier 2" toProperty="tumor_bam_file" />
  <link fromOperation="input connector" fromProperty="tier_2_snp_high_confidence_file" toOperation="High Confidence Snp Tier 2" toProperty="output_file" />
  <link fromOperation="input connector" fromProperty="only_tier_1" toOperation="High Confidence Snp Tier 2" toProperty="skip" /> 
  <link fromOperation="Tier Variants Snp" fromProperty="tier2_file" toOperation="High Confidence Snp Tier 2" toProperty="sniper_file" />

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="High Confidence Snp Tier 3" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="min_mapping_quality" toOperation="High Confidence Snp Tier 3" toProperty="min_mapping_quality" />
  <link fromOperation="input connector" fromProperty="min_somatic_quality" toOperation="High Confidence Snp Tier 3" toProperty="min_somatic_quality" />
  <link fromOperation="input connector" fromProperty="tumor_bam_file" toOperation="High Confidence Snp Tier 3" toProperty="tumor_bam_file" />
  <link fromOperation="input connector" fromProperty="tier_3_snp_high_confidence_file" toOperation="High Confidence Snp Tier 3" toProperty="output_file" />
  <link fromOperation="input connector" fromProperty="only_tier_1" toOperation="High Confidence Snp Tier 3" toProperty="skip" /> 
  <link fromOperation="Tier Variants Snp" fromProperty="tier3_file" toOperation="High Confidence Snp Tier 3" toProperty="sniper_file" />

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="High Confidence Snp Tier 4" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="min_mapping_quality" toOperation="High Confidence Snp Tier 4" toProperty="min_mapping_quality" />
  <link fromOperation="input connector" fromProperty="min_somatic_quality" toOperation="High Confidence Snp Tier 4" toProperty="min_somatic_quality" />
  <link fromOperation="input connector" fromProperty="tumor_bam_file" toOperation="High Confidence Snp Tier 4" toProperty="tumor_bam_file" />
  <link fromOperation="input connector" fromProperty="tier_4_snp_high_confidence_file" toOperation="High Confidence Snp Tier 4" toProperty="output_file" />
  <link fromOperation="input connector" fromProperty="only_tier_1" toOperation="High Confidence Snp Tier 4" toProperty="skip" /> 
  <link fromOperation="Tier Variants Snp" fromProperty="tier4_file" toOperation="High Confidence Snp Tier 4" toProperty="sniper_file" />

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
  <link fromOperation="Somatic Sniper" fromProperty="output_indel_file" toOperation="Library Support Filter" toProperty="indel_file" />

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Sniper Adaptor Indel" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="adaptor_output_indel" toOperation="Sniper Adaptor Indel" toProperty="output_file" />
  <link fromOperation="Library Support Filter" fromProperty="preferred_output_file" toOperation="Sniper Adaptor Indel" toProperty="somatic_file" />

  <link fromOperation="Varscan ProcessSomatic Indel" fromProperty="somatic_out" toOperation="Merge Indels" toProperty="varscan_file" />
  <link fromOperation="Sniper Adaptor Indel" fromProperty="output_file" toOperation="Merge Indels" toProperty="glf_file" />
  <link fromOperation="input connector" fromProperty="merged_indel_output" toOperation="Merge Indels" toProperty="output_file" />

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Annotate Transcript Variants Indel" toProperty="skip_if_output_present" />
  <link fromOperation="Merge Indels" fromProperty="output_file" toOperation="Annotate Transcript Variants Indel" toProperty="variant_file" />
  <link fromOperation="input connector" fromProperty="annotate_output_indel" toOperation="Annotate Transcript Variants Indel" toProperty="output_file" />
  <link fromOperation="input connector" fromProperty="annotate_no_headers" toOperation="Annotate Transcript Variants Indel" toProperty="no_headers" />
  <link fromOperation="input connector" fromProperty="transcript_annotation_filter" toOperation="Annotate Transcript Variants Indel" toProperty="annotation_filter" />

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Tier Variants Indel" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="tier_1_indel_file" toOperation="Tier Variants Indel" toProperty="tier1_file" />
  <link fromOperation="input connector" fromProperty="only_tier_1_indel" toOperation="Tier Variants Indel" toProperty="only_tier_1" />
  <link fromOperation="Sniper Adaptor Indel" fromProperty="output_file" toOperation="Tier Variants Indel" toProperty="variant_file" />
  <link fromOperation="Annotate Transcript Variants Indel" fromProperty="output_file" toOperation="Tier Variants Indel" toProperty="transcript_annotation_file" />

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Plot Circos" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="circos_graph" toOperation="Plot Circos" toProperty="output_file" />
  <link fromOperation="Copy Number Alteration" fromProperty="output_file" toOperation="Plot Circos" toProperty="cna_file" />
  <link fromOperation="Breakdancer" fromProperty="breakdancer_output" toOperation="Plot Circos" toProperty="sv_file" />
  <link fromOperation="Upload Variants Snp Tier 1" fromProperty="output_file" toOperation="Plot Circos" toProperty="tier1_hclabel_file" />

  <link fromOperation="Tier Variants Indel" fromProperty="tier1_file" toOperation="Upload Variants Indel" toProperty="variant_file" />
  <link fromOperation="Annotate Transcript Variants Indel" fromProperty="output_file" toOperation="Upload Variants Indel" toProperty="annotation_file" />
  <link fromOperation="input connector" fromProperty="upload_variants_indel_output" toOperation="Upload Variants Indel" toProperty="output_file" />
  <link fromOperation="input connector" fromProperty="build_id" toOperation="Upload Variants Indel" toProperty="build_id" />

  <link fromOperation="input connector" fromProperty="build_id" toOperation="Wait for Database Upload" toProperty="build_id" />
  <link fromOperation="Upload Variants Indel" fromProperty="result" toOperation="Wait for Database Upload" toProperty="upload indel result" />
  <link fromOperation="Upload Variants Snp Tier 2" fromProperty="result" toOperation="Wait for Database Upload" toProperty="upload snp tier 2 result" />
  <link fromOperation="Plot Circos" fromProperty="result" toOperation="Wait for Database Upload" toProperty="plot circos result" />

  <link fromOperation="Wait for Database Upload" fromProperty="build_id" toOperation="Generate Report" toProperty="build_id" />
  <link fromOperation="input connector" fromProperty="report_output" toOperation="Generate Report" toProperty="report_output" />
  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Generate Report" toProperty="skip_if_output_present" />

  <link fromOperation="Plot Circos" fromProperty="output_file" toOperation="output connector" toProperty="circos_big_graph" />
  <link fromOperation="Upload Variants Indel" fromProperty="output_file" toOperation="output connector" toProperty="tier_1_indel_output" />
  <link fromOperation="Generate Report" fromProperty="report_output" toOperation="output connector" toProperty="final_report_output" />
  

  <operation name="Somatic Sniper">
    <operationtype commandClass="Genome::Model::Tools::Somatic::Sniper" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operation name="Varscan Somatic">
    <operationtype commandClass="Genome::Model::Tools::Varscan::Somatic" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operation name="Varscan ProcessSomatic SNP">
    <operationtype commandClass="Genome::Model::Tools::Varscan::ProcessSomatic" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operation name="Varscan ProcessSomatic Indel">
    <operationtype commandClass="Genome::Model::Tools::Varscan::ProcessSomatic" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operation name="Format Varscan Indels">
    <operationtype commandClass="Genome::Model::Tools::Capture::FormatIndels" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operation name="Format Varscan Snvs">
    <operationtype commandClass="Genome::Model::Tools::Capture::FormatSnvs" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operation name="Merge SNPs">
    <operationtype commandClass="Genome::Model::Tools::Capture::MergeVariantCalls" typeClass="Workflow::OperationType::Command" />
  </operation>  

  <operation name="Merge Indels">
    <operationtype commandClass="Genome::Model::Tools::Capture::MergeAdaptedIndels" typeClass="Workflow::OperationType::Command" />
  </operation>  



  <operation name="Breakdancer">
    <operationtype commandClass="Genome::Model::Tools::Somatic::Breakdancer" typeClass="Workflow::OperationType::Command" />
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
  <operation name="Annotate UCSC">
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
  <operation name="Tier Variants Indel">
    <operationtype commandClass="Genome::Model::Tools::Somatic::TierVariants" typeClass="Workflow::OperationType::Command" />
  </operation>
  <operation name="Upload Variants Indel">
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

  <operation name="Generate Report">
    <operationtype commandClass="Genome::Model::Tools::Somatic::VariantReport" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operationtype typeClass="Workflow::OperationType::Model">
    <inputproperty>normal_bam_file</inputproperty>
    <inputproperty>tumor_bam_file</inputproperty>
    <inputproperty>build_id</inputproperty>
    <inputproperty isOptional="Y">skip_if_output_present</inputproperty>
    <inputproperty isOptional="Y">tumor_snp_file</inputproperty>
    <inputproperty isOptional="Y">normal_snp_file</inputproperty>
    <inputproperty isOptional="Y">reference_fasta</inputproperty>

    <inputproperty isOptional="Y">only_tier_1</inputproperty>
    <inputproperty isOptional="Y">only_tier_1_indel</inputproperty>
    <inputproperty isOptional="Y">skip_sv</inputproperty>

    <inputproperty isOptional="Y">data_directory</inputproperty>
    <inputproperty isOptional="Y">sniper_snp_output</inputproperty>
    <inputproperty isOptional="Y">sniper_indel_output</inputproperty>

    <inputproperty isOptional="Y">breakdancer_config_file</inputproperty>
    <inputproperty isOptional="Y">breakdancer_output_file</inputproperty>
    
    <inputproperty isOptional="Y">copy_number_output</inputproperty>

    <inputproperty isOptional="Y">normal_indelpe_data_directory</inputproperty>
    <inputproperty isOptional="Y">tumor_indelpe_data_directory</inputproperty>

    <inputproperty isOptional="Y">snp_filter_output</inputproperty>

    <inputproperty isOptional="Y">varscan_snp_output</inputproperty>
    <inputproperty isOptional="Y">varscan_snp_germline</inputproperty>
    <inputproperty isOptional="Y">varscan_snp_loh</inputproperty>
    <inputproperty isOptional="Y">varscan_snp_somatic</inputproperty>
    <inputproperty isOptional="Y">varscan_indel_output</inputproperty>
    <inputproperty isOptional="Y">varscan_indel_germline</inputproperty>
    <inputproperty isOptional="Y">varscan_indel_loh</inputproperty>
    <inputproperty isOptional="Y">varscan_indel_somatic</inputproperty>
    <inputproperty isOptional="Y">varscan_adaptor_snp</inputproperty>
    <inputproperty isOptional="Y">varscan_adaptor_indel</inputproperty>
    <inputproperty isOptional="Y">merged_snp_output</inputproperty>
    <inputproperty isOptional="Y">merged_snp_output_varscan</inputproperty>
    <inputproperty isOptional="Y">merged_snp_output_glf</inputproperty>
    <inputproperty isOptional="Y">merged_snp_output_shared</inputproperty>

    <inputproperty isOptional="Y">merged_snp_filter</inputproperty>
    <inputproperty isOptional="Y">merged_indel_output</inputproperty>
    <inputproperty isOptional="Y">merged_germline_snp</inputproperty>
    <inputproperty isOptional="Y">merged_loh_snp</inputproperty>
    <inputproperty isOptional="Y">annotate_output_germline_snp</inputproperty>
    <inputproperty isOptional="Y">annotate_output_germline_indel</inputproperty>
    <inputproperty isOptional="Y">tier_1_germline_snp_file</inputproperty>
    <inputproperty isOptional="Y">tier_1_germline_indel_file</inputproperty>
    
    <inputproperty isOptional="Y">filter_ceu_yri_output</inputproperty>
            
    <inputproperty isOptional="Y">adaptor_output_snp</inputproperty>

    <inputproperty isOptional="Y">dbsnp_output</inputproperty>
    <inputproperty isOptional="Y">lookup_variants_report_mode</inputproperty>
    <inputproperty isOptional="Y">lookup_variants_filter_out_submitters</inputproperty>

    <inputproperty isOptional="Y">loh_output_file</inputproperty>
    <inputproperty isOptional="Y">loh_fail_output_file</inputproperty>

    <inputproperty isOptional="Y">annotate_output_snp</inputproperty>
    <inputproperty isOptional="Y">annotate_no_headers</inputproperty>
    <inputproperty isOptional="Y">transcript_annotation_filter</inputproperty>
    
    <inputproperty isOptional="Y">ucsc_output</inputproperty>
    <inputproperty isOptional="Y">ucsc_unannotated_output</inputproperty>

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
    <inputproperty isOptional="Y">upload_variants_indel_output</inputproperty>
    
    <inputproperty isOptional="Y">tier_1_indel_file</inputproperty>
    <inputproperty isOptional="Y">tier_1_indel_high_confidence_file</inputproperty>

    <outputproperty>tier_1_snp_high_confidence</outputproperty>
    <outputproperty>tier_2_snp_high_confidence</outputproperty>
    <outputproperty>tier_3_snp_high_confidence</outputproperty>
    <outputproperty>tier_4_snp_high_confidence</outputproperty>

    <inputproperty isOptional="Y">indel_lib_filter_preferred_output</inputproperty>
    <inputproperty isOptional="Y">indel_lib_filter_single_output</inputproperty>
    <inputproperty isOptional="Y">indel_lib_filter_multi_output</inputproperty>
    <inputproperty isOptional="Y">adaptor_output_indel</inputproperty>
    <inputproperty isOptional="Y">annotate_output_indel</inputproperty>
   
    <inputproperty isOptional="Y">indel_capture_filter_output</inputproperty>
   
    <inputproperty isOptional="Y">circos_graph</inputproperty>

    <inputproperty isOptional="Y">report_output</inputproperty>

    <outputproperty>somatic_snp_merged</outputproperty>
    <outputproperty>somatic_snp_unique1</outputproperty>
    <outputproperty>somatic_snp_unique2</outputproperty>
    <outputproperty>somatic_snp_shared</outputproperty>
    <outputproperty>somatic_indel</outputproperty>

    <outputproperty>tier_1_indel_output</outputproperty>
    <outputproperty>circos_big_graph</outputproperty>
    <outputproperty>final_report_output</outputproperty>
  </operationtype>

</workflow>


