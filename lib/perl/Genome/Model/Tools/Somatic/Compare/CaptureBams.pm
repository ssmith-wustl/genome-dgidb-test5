package Genome::Model::Tools::Somatic::Compare::CaptureBams;

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

use Genome;

class Genome::Model::Tools::Somatic::Compare::CaptureBams {
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
        $self->reference_fasta(Genome::Config::reference_sequence_directory() . '/NCBI-human-build36/all_sequences.fa');
    }

    # Default high confidence parameters 
    unless (defined $self->min_mapping_quality) {
        $self->min_mapping_quality(40);
    }
    unless (defined $self->min_somatic_quality) {
        $self->min_somatic_quality(40);
    }

    ## Optional chr-prepending for external BAMs ##
    unless (defined $self->prepend_chr) {
        $self->prepend_chr(0);
    }

    return 1;
}

sub default_filenames{
    my $self = shift;
   
    my %default_filenames = (
        breakdancer_working_directory       => 'breakdancer/',
        sniper_working_directory            => 'sniper/',
                

        ## glfSomatic Output Files ##
        sniper_snp_output_adaptor           => 'somaticSniper.output.snp.adaptor',
        sniper_snp_output_filter            => 'somaticSniper.output.snp.filter',
        sniper_snp_output_filter_hc         => 'somaticSniper.output.snp.filter.hc',
        sniper_snp_output_filter_hc_somatic => 'somaticSniper.output.snp.filter.hc.somatic',
        sniper_snp_output_filter_hc_loh     => 'somaticSniper.output.snp.filter.hc.loh',

        ## Files formatted for annotation ##
        
       adaptor_output_indel                => 'somaticSniper.output.indel.formatted',
       filter_indel_output                 => 'somaticSniper.output.indel.formatted.filter',

        ## VarScan Output Files ##
        varscan_snp_output                  => 'varScan.output.snp',
#        varscan_snp_output_filter           => 'varScan.output.snp.filter',
        varscan_indel_output                => 'varScan.output.indel',

        varscan_adaptor_snp                 => 'varScan.output.snp.formatted',
        varscan_adaptor_indel               => 'varScan.output.indel.formatted',
        varscan_snp_germline                => 'varScan.output.snp.formatted.Germline',
        varscan_snp_loh                     => 'varScan.output.snp.formatted.LOH',
        varscan_snp_somatic                 => 'varScan.output.snp.formatted.Somatic.hc',
       
        varscan_indel_germline              => 'varScan.output.indel.formatted.Germline',
        varscan_indel_loh                   => 'varScan.output.indel.formatted.LOH',
        varscan_indel_somatic               => 'varScan.output.indel.formatted.Somatic',

        ## GATK Files ##

        gatk_output                         => 'gatk.output.indel',
        gatk_output_formatted               => 'gatk.output.indel.formatted',
        gatk_output_somatic                 => 'gatk.output.indel.formatted.Somatic',
        annotate_output_gatk_indel   => 'annotation.somatic.gatk-indel.transcript',        
        gatk_output_tier1                   => 'gatk.output.indel.formatted.Somatic.tier1',
        
        ## Combined glfSomatic+VarScan Output files ##
        merged_snp_output                   => 'merged.somatic.snp',            ## Generated from merge-variants of somaticSniper and varScan
        merged_indel_output                 => 'merged.somatic.indel',          ## Generated from merge-variants of somaticSniper and varScan ##
        merged_indel_output_filter          => 'merged.somatic.indel.filter',          ## The homopolymer-filtered list of indels ##
        
        ## Strand Filtering and Lookup Variants Files ##
        merged_snp_output_filter        => 'merged.somatic.snp.filter',
        merged_snp_output_filter_fail   => 'merged.somatic.snp.filter.removed',
        merged_snp_output_novel         => 'merged.somatic.snp.filter.novel',


        ## Annotation output files ##
        annotate_output_snp                 => 'annotation.somatic.snp.transcript',
        ucsc_output                         => 'annotation.somatic.snp.ucsc',
        ucsc_unannotated_output             => 'annotation.somatic.snp.unannot-ucsc',
        
        annotate_output_indel                 => 'annotation.somatic.indel.transcript',

        ## Tiered SNP and indel files (all confidence) ##

        tier_1_snp_file                     => 'merged.somatic.snp.filter.novel.tier1',
        tier_2_snp_file                     => 'merged.somatic.snp.filter.novel.tier2',
        tier_3_snp_file                     => 'merged.somatic.snp.filter.novel.tier3',
        tier_4_snp_file                     => 'merged.somatic.snp.filter.novel.tier4',
        tier_1_indel_file                   => 'merged.somatic.indel.filter.tier1',

        ## Tiered SNP/indel files (high and highest conf ) ##
        
        tier_1_snp_file_high                => 'merged.somatic.snp.filter.novel.tier1.hc',
        tier_1_snp_file_highest             => 'merged.somatic.snp.filter.novel.tier1.gc',
        tier_1_indel_file_high              => 'merged.somatic.indel.filter.tier1.hc',
        tier_1_indel_file_highest           => 'merged.somatic.indel.filter.tier1.gc',

        ## Breakdancer and Copy Number files ##

        copy_number_output                  => 'copy_number.csv',
        circos_graph                        => 'circos_graph',
        variant_report_output               => 'cancer_report.html', 
        file_summary_report_output          => 'file_summary_report.html',
        

        upload_variants_snp_1_output        => 'upload-variants.snp_1.out',
        upload_variants_snp_2_output        => 'upload-variants.snp_2.out',
        upload_variants_indel_output        => 'upload-variants.indel.out',
    );

    return %default_filenames;
}

1;
__DATA__
<?xml version='1.0' standalone='yes'?>

<workflow name="Somatic Pipeline" logDir="/gsc/var/log/genome/somatic_capture_pipeline">

<!-- SOMATIC SNIPER -->
  <operation name="Somatic Sniper">
    <operationtype commandClass="Genome::Model::Tools::DetectVariants::Somatic::Sniper" typeClass="Workflow::OperationType::Command" />
  </operation>
  
  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Somatic Sniper" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="normal_bam_file" toOperation="Somatic Sniper" toProperty="control_aligned_reads_input" />
  <link fromOperation="input connector" fromProperty="tumor_bam_file" toOperation="Somatic Sniper" toProperty="aligned_reads_input" />
  <link fromOperation="input connector" fromProperty="reference_fasta" toOperation="Somatic Sniper" toProperty="reference_sequence_input" />
  <link fromOperation="input connector" fromProperty="sniper_working_directory" toOperation="Somatic Sniper" toProperty="output_directory" />


<!-- INDEL PE RUNNER -->

  <link fromOperation="input connector" fromProperty="tumor_bam_file" toOperation="Indelpe Runner Tumor" toProperty="bam_file" />
  <link fromOperation="input connector" fromProperty="reference_fasta" toOperation="Indelpe Runner Tumor" toProperty="ref_seq_file" />
  <link fromOperation="input connector" fromProperty="tumor_indelpe_data_directory" toOperation="Indelpe Runner Tumor" toProperty="output_dir" />
  <link fromOperation="input connector" fromProperty="tumor_snp_file" toOperation="Indelpe Runner Tumor" toProperty="filtered_snp_file" />

  <link fromOperation="input connector" fromProperty="normal_bam_file" toOperation="Indelpe Runner Normal" toProperty="bam_file" />
  <link fromOperation="input connector" fromProperty="reference_fasta" toOperation="Indelpe Runner Normal" toProperty="ref_seq_file" />
  <link fromOperation="input connector" fromProperty="normal_indelpe_data_directory" toOperation="Indelpe Runner Normal" toProperty="output_dir" />
  <link fromOperation="input connector" fromProperty="normal_snp_file" toOperation="Indelpe Runner Normal" toProperty="filtered_snp_file" />


<!-- FILTER SOMATIC SNIPER SNPS -->

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Snp Filter" toProperty="skip_if_output_present" />
  <link fromOperation="Indelpe Runner Tumor" fromProperty="filtered_snp_file" toOperation="Snp Filter" toProperty="tumor_snp_file" />
  <link fromOperation="input connector" fromProperty="sniper_snp_output_filter" toOperation="Snp Filter" toProperty="output_file" />
  <link fromOperation="Somatic Sniper" fromProperty="snv_output" toOperation="Snp Filter" toProperty="sniper_snp_file" />

<!-- FORMAT FILTERED SNIPER SNPS -->

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Sniper Adaptor Snp" toProperty="skip_if_output_present" />
  <link fromOperation="Snp Filter" fromProperty="output_file" toOperation="Sniper Adaptor Snp" toProperty="somatic_file" />
  <link fromOperation="input connector" fromProperty="sniper_snp_output_adaptor" toOperation="Sniper Adaptor Snp" toProperty="output_file" />

<!-- FORMAT SNIPER INDELS -->

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Sniper Adaptor Indel" toProperty="skip_if_output_present" />
  <link fromOperation="Somatic Sniper" fromProperty="indel_output" toOperation="Sniper Adaptor Indel" toProperty="somatic_file" />
  <link fromOperation="input connector" fromProperty="adaptor_output_indel" toOperation="Sniper Adaptor Indel" toProperty="output_file" />

<!-- FILTER SNIPER INDELS -->

  <link fromOperation="Sniper Adaptor Indel" fromProperty="output_file" toOperation="Filter Sniper Indel" toProperty="variants_file" />
  <link fromOperation="input connector" fromProperty="filter_indel_output" toOperation="Filter Sniper Indel" toProperty="output_file" />

<!-- ISOLATE HIGH CONFIDENCE SNIPER SNPS -->

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="High Confidence Snp" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="min_mapping_quality" toOperation="High Confidence Snp" toProperty="min_mapping_quality" />
  <link fromOperation="input connector" fromProperty="min_somatic_quality" toOperation="High Confidence Snp" toProperty="min_somatic_quality" />
  <link fromOperation="input connector" fromProperty="prepend_chr" toOperation="High Confidence Snp" toProperty="prepend_chr" />  
  <link fromOperation="input connector" fromProperty="tumor_bam_file" toOperation="High Confidence Snp" toProperty="tumor_bam_file" />
  <link fromOperation="Sniper Adaptor Snp" fromProperty="output_file" toOperation="High Confidence Snp" toProperty="sniper_file" />
  <link fromOperation="input connector" fromProperty="sniper_snp_output_filter_hc" toOperation="High Confidence Snp" toProperty="output_file" />

<!-- RUN LOH FILTER ON SOMATIC SNIPER FILES --> 

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Filter Loh" toProperty="skip_if_output_present" />
  <link fromOperation="Indelpe Runner Normal" fromProperty="filtered_snp_file" toOperation="Filter Loh" toProperty="normal_snp_file" />
  <link fromOperation="High Confidence Snp" fromProperty="output_file" toOperation="Filter Loh" toProperty="tumor_snp_file" />
  <link fromOperation="input connector" fromProperty="sniper_snp_output_filter_hc_somatic" toOperation="Filter Loh" toProperty="output_file" />
  <link fromOperation="input connector" fromProperty="sniper_snp_output_filter_hc_loh" toOperation="Filter Loh" toProperty="loh_output_file" />


<!-- VARSCAN2 SOMATIC -->

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Varscan Somatic" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="normal_bam_file" toOperation="Varscan Somatic" toProperty="normal_bam" />
  <link fromOperation="input connector" fromProperty="tumor_bam_file" toOperation="Varscan Somatic" toProperty="tumor_bam" />
  <link fromOperation="input connector" fromProperty="reference_fasta" toOperation="Varscan Somatic" toProperty="reference" />
  <link fromOperation="input connector" fromProperty="varscan_snp_output" toOperation="Varscan Somatic" toProperty="output_snp" />
  <link fromOperation="input connector" fromProperty="varscan_indel_output" toOperation="Varscan Somatic" toProperty="output_indel" />


<!-- FORMAT VARSCAN SNPS/INDELS -->

  <link fromOperation="Varscan Somatic" fromProperty="output_snp" toOperation="Format Varscan Snvs" toProperty="variants_file" />
  <link fromOperation="input connector" fromProperty="varscan_adaptor_snp" toOperation="Format Varscan Snvs" toProperty="output_file" />

  <link fromOperation="Varscan Somatic" fromProperty="output_indel" toOperation="Format Varscan Indels" toProperty="variants_file" />
  <link fromOperation="input connector" fromProperty="varscan_adaptor_indel" toOperation="Format Varscan Indels" toProperty="output_file" />
  

<!-- PROCESS FORMATTED VARSCAN SNPS/INDELS -->

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Varscan ProcessSomatic SNP" toProperty="skip_if_output_present" />
  <link fromOperation="Format Varscan Snvs" fromProperty="output_file" toOperation="Varscan ProcessSomatic SNP" toProperty="status_file" />
  <link fromOperation="input connector" fromProperty="varscan_snp_somatic" toOperation="Varscan ProcessSomatic SNP" toProperty="somatic_out" />  

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Varscan ProcessSomatic Indel" toProperty="skip_if_output_present" />
  <link fromOperation="Format Varscan Indels" fromProperty="output_file" toOperation="Varscan ProcessSomatic Indel" toProperty="status_file" />
  <link fromOperation="input connector" fromProperty="varscan_indel_somatic" toOperation="Varscan ProcessSomatic Indel" toProperty="somatic_out" />


<!-- RUN GATK SOMATIC INDEL -->
  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Gatk Somatic Indel" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="normal_bam_file" toOperation="Gatk Somatic Indel" toProperty="normal_bam" />
  <link fromOperation="input connector" fromProperty="tumor_bam_file" toOperation="Gatk Somatic Indel" toProperty="tumor_bam" />
  <link fromOperation="input connector" fromProperty="gatk_output" toOperation="Gatk Somatic Indel" toProperty="output_file" />
  <link fromOperation="input connector" fromProperty="gatk_output_formatted" toOperation="Gatk Somatic Indel" toProperty="formatted_file" />
  <link fromOperation="input connector" fromProperty="gatk_output_somatic" toOperation="Gatk Somatic Indel" toProperty="somatic_file" />

<!-- RUN ANNOTATION ON GATK SOMATIC INDELS -->

  <link fromOperation="Gatk Somatic Indel" fromProperty="somatic_file" toOperation="Annotate Transcript Variants Gatk Indel" toProperty="variant_file" />
  <link fromOperation="input connector" fromProperty="annotate_output_gatk_indel" toOperation="Annotate Transcript Variants Gatk Indel" toProperty="output_file" />
  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Annotate Transcript Variants Gatk Indel" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="annotate_no_headers" toOperation="Annotate Transcript Variants Gatk Indel" toProperty="no_headers" />
  <link fromOperation="input connector" fromProperty="transcript_annotation_filter" toOperation="Annotate Transcript Variants Gatk Indel" toProperty="annotation_filter" />

<!-- ISOLATE TIER 1 GATK SOMATIC INDELS -->

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Tier Variants Gatk Indel" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="only_tier_1_indel" toOperation="Tier Variants Gatk Indel" toProperty="only_tier_1" />
  <link fromOperation="Gatk Somatic Indel" fromProperty="somatic_file" toOperation="Tier Variants Gatk Indel" toProperty="variant_file" />
  <link fromOperation="Annotate Transcript Variants Gatk Indel" fromProperty="output_file" toOperation="Tier Variants Gatk Indel" toProperty="transcript_annotation_file" />
  <link fromOperation="input connector" fromProperty="gatk_output_tier1" toOperation="Tier Variants Gatk Indel" toProperty="tier1_file" />

  <link fromOperation="Tier Variants Gatk Indel" fromProperty="tier1_file" toOperation="output connector" toProperty="tier1_gatk_indel_file" />


<!-- MERGE FILTERED SNIPER SNPS AND VARSCAN SNPS -->

  <link fromOperation="Varscan ProcessSomatic SNP" fromProperty="somatic_out" toOperation="Merge SNPs" toProperty="varscan_file" />
  <link fromOperation="Filter Loh" fromProperty="output_file" toOperation="Merge SNPs" toProperty="glf_file" />
  <link fromOperation="input connector" fromProperty="merged_snp_output" toOperation="Merge SNPs" toProperty="output_file" />


<!-- RUN STRAND FILTER ON MERGED SNPS -->

  <link fromOperation="Merge SNPs" fromProperty="output_file" toOperation="Strand Filter" toProperty="variant_file" />
  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Strand Filter" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="merged_snp_output_filter" toOperation="Strand Filter" toProperty="output_file" />
  <link fromOperation="input connector" fromProperty="merged_snp_output_filter_fail" toOperation="Strand Filter" toProperty="filtered_file" />
  <link fromOperation="input connector" fromProperty="tumor_bam_file" toOperation="Strand Filter" toProperty="tumor_bam_file" />

<!-- DO NOT RUN CEU/YRI FILTER ON MERGED SOMATIC CALLS --> 
  
<!-- RUN DBSNP FILTER ON MERGED SOMATIC CALLS --> 

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Lookup Variants" toProperty="skip_if_output_present" />
  <link fromOperation="Strand Filter" fromProperty="output_file" toOperation="Lookup Variants" toProperty="variant_file" />
  <link fromOperation="input connector" fromProperty="lookup_variants_report_mode" toOperation="Lookup Variants" toProperty="report_mode" />
  <link fromOperation="input connector" fromProperty="lookup_variants_filter_out_submitters" toOperation="Lookup Variants" toProperty="filter_out_submitters" />
  <link fromOperation="input connector" fromProperty="merged_snp_output_novel" toOperation="Lookup Variants" toProperty="output_file" />

  
<!-- RUN TRANSCRIPT ANNOTATION FOR SNPS --> 
  
  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Annotate Transcript Variants Snp" toProperty="skip_if_output_present" />
  <link fromOperation="Lookup Variants" fromProperty="output_file" toOperation="Annotate Transcript Variants Snp" toProperty="variant_file" />
  <link fromOperation="input connector" fromProperty="annotate_output_snp" toOperation="Annotate Transcript Variants Snp" toProperty="output_file" />
  <link fromOperation="input connector" fromProperty="annotate_no_headers" toOperation="Annotate Transcript Variants Snp" toProperty="no_headers" />
  <link fromOperation="input connector" fromProperty="transcript_annotation_filter" toOperation="Annotate Transcript Variants Snp" toProperty="annotation_filter" />


<!-- RUN UCSC ANNOTATION FOR SNPS --> 

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Annotate UCSC" toProperty="skip_if_output_present" />
  <link fromOperation="Merge SNPs" fromProperty="output_file" toOperation="Annotate UCSC" toProperty="input_file" />
  <link fromOperation="input connector" fromProperty="ucsc_output" toOperation="Annotate UCSC" toProperty="output_file" /> 
  <link fromOperation="input connector" fromProperty="ucsc_unannotated_output" toOperation="Annotate UCSC" toProperty="unannotated_file" /> 
  <link fromOperation="input connector" fromProperty="only_tier_1" toOperation="Annotate UCSC" toProperty="skip" /> 

<!-- DIVIDE VARIANTS BY TIER -->
    
  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Tier Variants Snp" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="tier_1_snp_file" toOperation="Tier Variants Snp" toProperty="tier1_file" />
  <link fromOperation="input connector" fromProperty="tier_2_snp_file" toOperation="Tier Variants Snp" toProperty="tier2_file" />
  <link fromOperation="input connector" fromProperty="tier_3_snp_file" toOperation="Tier Variants Snp" toProperty="tier3_file" />
  <link fromOperation="input connector" fromProperty="tier_4_snp_file" toOperation="Tier Variants Snp" toProperty="tier4_file" />
  <link fromOperation="input connector" fromProperty="only_tier_1" toOperation="Tier Variants Snp" toProperty="only_tier_1" />
  <link fromOperation="Lookup Variants" fromProperty="output_file" toOperation="Tier Variants Snp" toProperty="variant_file" />
  <link fromOperation="Annotate UCSC" fromProperty="output_file" toOperation="Tier Variants Snp" toProperty="ucsc_file" />
  <link fromOperation="Annotate Transcript Variants Snp" fromProperty="output_file" toOperation="Tier Variants Snp" toProperty="transcript_annotation_file" />

<!-- MERGE ADAPTED INDELS FROM SNIPER AND VARSCAN -->

  <link fromOperation="Varscan ProcessSomatic Indel" fromProperty="somatic_out" toOperation="Merge Indels" toProperty="varscan_file" />
  <link fromOperation="Filter Sniper Indel" fromProperty="output_file" toOperation="Merge Indels" toProperty="glf_file" />
  <link fromOperation="input connector" fromProperty="merged_indel_output" toOperation="Merge Indels" toProperty="output_file" />

<!-- RUN HOMOPOLYMER FILTER ON MERGED INDELS -->

  <link fromOperation="Merge Indels" fromProperty="output_file" toOperation="Monorun Filter Indel" toProperty="variant_file" />
  <link fromOperation="input connector" fromProperty="tumor_bam_file" toOperation="Monorun Filter Indel" toProperty="tumor_bam_file" />
  <link fromOperation="input connector" fromProperty="merged_indel_output_filter" toOperation="Monorun Filter Indel" toProperty="output_file" />

<!-- RUN TRANSCRIPT ANNOTATION FOR INDELS -->

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Annotate Transcript Variants Indel" toProperty="skip_if_output_present" />
  <link fromOperation="Monorun Filter Indel" fromProperty="output_file" toOperation="Annotate Transcript Variants Indel" toProperty="variant_file" />
  <link fromOperation="input connector" fromProperty="annotate_output_indel" toOperation="Annotate Transcript Variants Indel" toProperty="output_file" />
  <link fromOperation="input connector" fromProperty="annotate_no_headers" toOperation="Annotate Transcript Variants Indel" toProperty="no_headers" />
  <link fromOperation="input connector" fromProperty="transcript_annotation_filter" toOperation="Annotate Transcript Variants Indel" toProperty="annotation_filter" />

<!-- DIVIDE INDELS BY TIER -->

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Tier Variants Indel" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="only_tier_1_indel" toOperation="Tier Variants Indel" toProperty="only_tier_1" />
  <link fromOperation="Merge Indels" fromProperty="output_file" toOperation="Tier Variants Indel" toProperty="variant_file" />
  <link fromOperation="Annotate Transcript Variants Indel" fromProperty="output_file" toOperation="Tier Variants Indel" toProperty="transcript_annotation_file" />
  <link fromOperation="input connector" fromProperty="tier_1_indel_file" toOperation="Tier Variants Indel" toProperty="tier1_file" />

<!-- GROUP TIERED SNP CALLS INTO HIGH AND HIGHEST CONF -->

<link fromOperation="Tier Variants Snp" fromProperty="tier1_file" toOperation="Confidence Groups Snp Tier 1" toProperty="variant_file" />
<link fromOperation="Filter Loh" fromProperty="output_file" toOperation="Confidence Groups Snp Tier 1" toProperty="glf_file" />
<link fromOperation="Varscan ProcessSomatic SNP" fromProperty="somatic_out" toOperation="Confidence Groups Snp Tier 1" toProperty="varscan_file" />
<link fromOperation="input connector" fromProperty="tier_1_snp_file_high" toOperation="Confidence Groups Snp Tier 1" toProperty="output_high" />
<link fromOperation="input connector" fromProperty="tier_1_snp_file_highest" toOperation="Confidence Groups Snp Tier 1" toProperty="output_highest" />

<!-- GROUP TIERED INDEL CALLS INTO HIGH AND HIGHEST CONF -->
<link fromOperation="Tier Variants Indel" fromProperty="tier1_file" toOperation="Confidence Groups Indel Tier 1" toProperty="variant_file" />
<link fromOperation="Filter Sniper Indel" fromProperty="output_file"  toOperation="Confidence Groups Indel Tier 1" toProperty="glf_file" />
<link fromOperation="Varscan ProcessSomatic Indel" fromProperty="somatic_out" toOperation="Confidence Groups Indel Tier 1" toProperty="varscan_file" />
<link fromOperation="input connector" fromProperty="tier_1_indel_file_high" toOperation="Confidence Groups Indel Tier 1" toProperty="output_high" />
<link fromOperation="input connector" fromProperty="tier_1_indel_file_highest" toOperation="Confidence Groups Indel Tier 1" toProperty="output_highest" />

<!-- PROVIDE OUTPUT CONNECTION FOR ENDPOINT FILES -->

  <!--link fromOperation="Tier Variants Indel" fromProperty="tier1_file" toOperation="output connector" toProperty="tier_1_indel" /-->
  <link fromOperation="Confidence Groups Snp Tier 1" fromProperty="output_high" toOperation="output connector" toProperty="tier_1_snp_high" />
  <link fromOperation="Confidence Groups Snp Tier 1" fromProperty="output_highest" toOperation="output connector" toProperty="tier_1_snp_highest" />
  <link fromOperation="Confidence Groups Indel Tier 1" fromProperty="output_high" toOperation="output connector" toProperty="tier_1_indel_high" />
  <link fromOperation="Confidence Groups Indel Tier 1" fromProperty="output_highest" toOperation="output connector" toProperty="tier_1_indel_highest" />
  <link fromOperation="Tier Variants Snp" fromProperty="tier2_file" toOperation="output connector" toProperty="tier_2_snp" />
  <link fromOperation="Tier Variants Snp" fromProperty="tier3_file" toOperation="output connector" toProperty="tier_3_snp" />
  <link fromOperation="Tier Variants Snp" fromProperty="tier4_file" toOperation="output connector" toProperty="tier_4_snp" />


<!-- UPLOAD VARIANTS -->

  <link fromOperation="Tier Variants Snp" fromProperty="tier1_file" toOperation="Upload Variants Snp Tier 1" toProperty="variant_file" />
  <link fromOperation="Annotate Transcript Variants Snp" fromProperty="output_file" toOperation="Upload Variants Snp Tier 1" toProperty="annotation_file" />
  <link fromOperation="input connector" fromProperty="upload_variants_snp_1_output" toOperation="Upload Variants Snp Tier 1" toProperty="output_file" />
  <link fromOperation="input connector" fromProperty="build_id" toOperation="Upload Variants Snp Tier 1" toProperty="build_id" />

  <link fromOperation="Tier Variants Snp" fromProperty="tier2_file" toOperation="Upload Variants Snp Tier 2" toProperty="variant_file" />
  <link fromOperation="Annotate Transcript Variants Snp" fromProperty="output_file" toOperation="Upload Variants Snp Tier 2" toProperty="annotation_file" />
  <link fromOperation="input connector" fromProperty="upload_variants_snp_2_output" toOperation="Upload Variants Snp Tier 2" toProperty="output_file" />
  <link fromOperation="input connector" fromProperty="build_id" toOperation="Upload Variants Snp Tier 2" toProperty="build_id" />
  <link fromOperation="input connector" fromProperty="only_tier_1" toOperation="Upload Variants Snp Tier 2" toProperty="_skip" />

  <link fromOperation="Tier Variants Indel" fromProperty="tier1_file" toOperation="Upload Variants Indel" toProperty="variant_file" />
  <link fromOperation="Annotate Transcript Variants Indel" fromProperty="output_file" toOperation="Upload Variants Indel" toProperty="annotation_file" />
  <link fromOperation="input connector" fromProperty="upload_variants_indel_output" toOperation="Upload Variants Indel" toProperty="output_file" />
  <link fromOperation="input connector" fromProperty="build_id" toOperation="Upload Variants Indel" toProperty="build_id" />


<!-- RUN BREAKDANCER AND COPYNUMBER -->

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Breakdancer" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="normal_bam_file" toOperation="Breakdancer" toProperty="control_aligned_reads_input" />
  <link fromOperation="input connector" fromProperty="tumor_bam_file" toOperation="Breakdancer" toProperty="aligned_reads_input" />
  <link fromOperation="input connector" fromProperty="breakdancer_working_directory" toOperation="Breakdancer" toProperty="output_directory" />
  <link fromOperation="input connector" fromProperty="reference_fasta" toOperation="Breakdancer" toProperty="reference_sequence_input" />
  <link fromOperation="input connector" fromProperty="skip_sv" toOperation="Breakdancer" toProperty="skip" />
                


  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Copy Number Alteration" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="normal_bam_file" toOperation="Copy Number Alteration" toProperty="normal_bam_file" />
  <link fromOperation="input connector" fromProperty="tumor_bam_file" toOperation="Copy Number Alteration" toProperty="tumor_bam_file" />
  <link fromOperation="input connector" fromProperty="copy_number_output" toOperation="Copy Number Alteration" toProperty="output_file" />


<!-- PLOT CIRCOS -->

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Plot Circos" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="circos_graph" toOperation="Plot Circos" toProperty="output_file" />
  <link fromOperation="Copy Number Alteration" fromProperty="output_file" toOperation="Plot Circos" toProperty="cna_file" />
  <link fromOperation="Breakdancer" fromProperty="sv_output" toOperation="Plot Circos" toProperty="sv_file" />
  <link fromOperation="Upload Variants Snp Tier 1" fromProperty="output_file" toOperation="Plot Circos" toProperty="tier1_hclabel_file" />



<!-- WAIT FOR DATABASE UPLOAD -->
  
  <link fromOperation="input connector" fromProperty="build_id" toOperation="Wait for Database Upload" toProperty="build_id" />
  <link fromOperation="Upload Variants Indel" fromProperty="result" toOperation="Wait for Database Upload" toProperty="upload indel result" />
  <link fromOperation="Upload Variants Snp Tier 2" fromProperty="result" toOperation="Wait for Database Upload" toProperty="upload snp tier 2 result" />
  <link fromOperation="Plot Circos" fromProperty="result" toOperation="Wait for Database Upload" toProperty="plot circos result" />


<!-- GENERATE REPORT -->
 
  <link fromOperation="Wait for Database Upload" fromProperty="build_id" toOperation="Generate Reports" toProperty="build_id" />
  <link fromOperation="input connector" fromProperty="variant_report_output" toOperation="Generate Reports" toProperty="variant_report_output" />
  <link fromOperation="input connector" fromProperty="file_summary_report_output" toOperation="Generate Reports" toProperty="file_summary_report_output" />
  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Generate Reports" toProperty="skip_if_output_present" />

<!-- OUTPUT CONNECTORS -->
  <link fromOperation="Plot Circos" fromProperty="output_file" toOperation="output connector" toProperty="circos_big_graph" />
  <link fromOperation="Generate Reports" fromProperty="variant_report_output" toOperation="output connector" toProperty="final_variant_report_output" />
  


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

  <operation name="Gatk Somatic Indel">
    <operationtype commandClass="Genome::Model::Tools::Gatk::SomaticIndel" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operation name="Annotate Transcript Variants Gatk Indel">
    <operationtype commandClass="Genome::Model::Tools::Annotate::TranscriptVariants" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operation name="Merge SNPs">
    <operationtype commandClass="Genome::Model::Tools::Capture::MergeVariantCalls" typeClass="Workflow::OperationType::Command" />
  </operation>  

  <operation name="Merge Indels">
    <operationtype commandClass="Genome::Model::Tools::Capture::MergeAdaptedIndels" typeClass="Workflow::OperationType::Command" />
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
  <operation name="Sniper Adaptor Snp">
    <operationtype commandClass="Genome::Model::Tools::Annotate::Adaptor::Sniper" typeClass="Workflow::OperationType::Command" />
  </operation>
  <operation name="Sniper Adaptor Indel">
    <operationtype commandClass="Genome::Model::Tools::Annotate::Adaptor::Sniper" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operation name="Filter Sniper Indel">
    <operationtype commandClass="Genome::Model::Tools::Capture::FilterGlfIndels" typeClass="Workflow::OperationType::Command" />
  </operation>  

  <operation name="Monorun Filter Indel">
    <operationtype commandClass="Genome::Model::Tools::Somatic::MonorunFilter" typeClass="Workflow::OperationType::Command" />
  </operation>  

  <operation name="Strand Filter">
    <operationtype commandClass="Genome::Model::Tools::Somatic::StrandFilter" typeClass="Workflow::OperationType::Command" />
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
  <operation name="High Confidence Snp">
    <operationtype commandClass="Genome::Model::Tools::Somatic::HighConfidence" typeClass="Workflow::OperationType::Command" />
  </operation>
  <operation name="Confidence Groups Snp Tier 1">
    <operationtype commandClass="Genome::Model::Tools::Capture::ConfidenceGroups" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operation name="Annotate Transcript Variants Indel">
    <operationtype commandClass="Genome::Model::Tools::Annotate::TranscriptVariants" typeClass="Workflow::OperationType::Command" />
  </operation>
  <operation name="Tier Variants Indel">
    <operationtype commandClass="Genome::Model::Tools::Somatic::TierVariants" typeClass="Workflow::OperationType::Command" />
  </operation>
  <operation name="Tier Variants Gatk Indel">
    <operationtype commandClass="Genome::Model::Tools::Somatic::TierVariants" typeClass="Workflow::OperationType::Command" />
  </operation>
  <operation name="Confidence Groups Indel Tier 1">
    <operationtype commandClass="Genome::Model::Tools::Capture::ConfidenceGroups" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operation name="Breakdancer">
    <operationtype commandClass="Genome::Model::Tools::DetectVariants::Somatic::Breakdancer" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operation name="Copy Number Alteration">
    <operationtype commandClass="Genome::Model::Tools::Somatic::BamToCna" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operation name="Plot Circos">
    <operationtype commandClass="Genome::Model::Tools::Somatic::PlotCircos" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operation name="Upload Variants Snp Tier 1">
    <operationtype commandClass="Genome::Model::Tools::Somatic::UploadVariants" typeClass="Workflow::OperationType::Command" />
  </operation>
  <operation name="Upload Variants Snp Tier 2">
    <operationtype commandClass="Genome::Model::Tools::Somatic::UploadVariants" typeClass="Workflow::OperationType::Command" />
  </operation>
  <operation name="Upload Variants Indel">
    <operationtype commandClass="Genome::Model::Tools::Somatic::UploadVariants" typeClass="Workflow::OperationType::Command" />
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
    <operationtype commandClass="Genome::Model::SomaticCapture::Command::RunReports" typeClass="Workflow::OperationType::Command" />
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
    <inputproperty isOptional="Y">sniper_working_directory</inputproperty>

    <inputproperty isOptional="Y">normal_indelpe_data_directory</inputproperty>
    <inputproperty isOptional="Y">tumor_indelpe_data_directory</inputproperty>

    <inputproperty isOptional="Y">sniper_snp_output_filter</inputproperty>

    <inputproperty isOptional="Y">breakdancer_working_directory</inputproperty>
    
    <inputproperty isOptional="Y">copy_number_output</inputproperty>
    <inputproperty isOptional="Y">circos_graph</inputproperty>
    <inputproperty isOptional="Y">variant_report_output</inputproperty>
    <inputproperty isOptional="Y">file_summary_report_output</inputproperty>

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

    <inputproperty isOptional="Y">gatk_output</inputproperty>
    <inputproperty isOptional="Y">gatk_output_formatted</inputproperty>
    <inputproperty isOptional="Y">gatk_output_somatic</inputproperty>
    <inputproperty isOptional="Y">gatk_output_tier1</inputproperty>
    <inputproperty isOptional="Y">annotate_output_gatk_indel</inputproperty>
    
    

    <inputproperty isOptional="Y">merged_snp_output</inputproperty>
    <inputproperty isOptional="Y">merged_snp_output_novel</inputproperty>
    <inputproperty isOptional="Y">merged_snp_output_filter</inputproperty>
    <inputproperty isOptional="Y">merged_snp_output_filter_fail</inputproperty>
    <inputproperty isOptional="Y">merged_indel_output</inputproperty>
    <inputproperty isOptional="Y">merged_indel_output_filter</inputproperty>
            
    <inputproperty isOptional="Y">sniper_snp_output_adaptor</inputproperty>
    <inputproperty isOptional="Y">adaptor_output_indel</inputproperty>
    <inputproperty isOptional="Y">filter_indel_output</inputproperty>

    <inputproperty isOptional="Y">lookup_variants_report_mode</inputproperty>
    <inputproperty isOptional="Y">lookup_variants_filter_out_submitters</inputproperty>

    <inputproperty isOptional="Y">sniper_snp_output_filter_hc</inputproperty>
    <inputproperty isOptional="Y">sniper_snp_output_filter_hc_somatic</inputproperty>
    <inputproperty isOptional="Y">sniper_snp_output_filter_hc_loh</inputproperty>

    <inputproperty isOptional="Y">annotate_output_indel</inputproperty>
    <inputproperty isOptional="Y">annotate_output_snp</inputproperty>
    <inputproperty isOptional="Y">annotate_no_headers</inputproperty>
    <inputproperty isOptional="Y">transcript_annotation_filter</inputproperty>
    
    <inputproperty isOptional="Y">ucsc_output</inputproperty>
    <inputproperty isOptional="Y">ucsc_unannotated_output</inputproperty>

    <inputproperty isOptional="Y">tier_1_indel_file</inputproperty>
    <inputproperty isOptional="Y">tier_1_snp_file</inputproperty>
    <inputproperty isOptional="Y">tier_2_snp_file</inputproperty>
    <inputproperty isOptional="Y">tier_3_snp_file</inputproperty>
    <inputproperty isOptional="Y">tier_4_snp_file</inputproperty>

    <inputproperty isOptional="Y">tier_1_snp_file_high</inputproperty>
    <inputproperty isOptional="Y">tier_1_snp_file_highest</inputproperty>

    <inputproperty isOptional="Y">tier_1_indel_file_high</inputproperty>
    <inputproperty isOptional="Y">tier_1_indel_file_highest</inputproperty>

    <inputproperty isOptional="Y">min_mapping_quality</inputproperty>
    <inputproperty isOptional="Y">min_somatic_quality</inputproperty>
    
    <inputproperty isOptional="Y">prepend_chr</inputproperty>

    <inputproperty isOptional="Y">upload_variants_snp_1_output</inputproperty>
    <inputproperty isOptional="Y">upload_variants_snp_2_output</inputproperty>
    <inputproperty isOptional="Y">upload_variants_indel_output</inputproperty>
<!--
    <inputproperty isOptional="Y">tier_1_snp_high_confidence</inputproperty>
    <inputproperty isOptional="Y">tier_2_snp_high_confidence_file</inputproperty>
    <inputproperty isOptional="Y">tier_3_snp_high_confidence_file</inputproperty>
    <inputproperty isOptional="Y">tier_4_snp_high_confidence_file</inputproperty>
-->
    <outputproperty>circos_big_graph</outputproperty>
    <outputproperty>final_variant_report_output</outputproperty>

    <outputproperty>tier_1_indel_high</outputproperty>
    <outputproperty>tier_1_indel_highest</outputproperty>    
    <outputproperty>tier_1_snp_high</outputproperty>
    <outputproperty>tier_1_snp_highest</outputproperty>
    <outputproperty>tier_2_snp</outputproperty>
    <outputproperty>tier_3_snp</outputproperty>
    <outputproperty>tier_4_snp</outputproperty>
    <outputproperty>tier1_gatk_indel_file</outputproperty>


  </operationtype>

</workflow>


