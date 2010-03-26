package Genome::Model::Tools::Germline::CaptureBams;

########################################################################################################################
# CaptureBams.pm - A module for comparing tumor-normal BAM files in capture data
#
#   
########################################################################################################################

use strict;
use warnings;

class Genome::Model::Tools::Germline::CaptureBams {
    is => ['Workflow::Operation::Command'],
    workflow => sub { Workflow::Operation->create_from_xml(\*DATA); }
};

sub help_brief {
    "Runs the **capture** germline pipeline workflow."
}

sub help_synopsis{
    my $self = shift;
    return <<"EOS"

example:
gmt germline capture-bams --build-id=101625141 --filtered-indelpe-snps='/gscmnt/sata835/info/medseq/model_data/2852971605/build101625141/sam_snp_related_metrics/filtered.indelpe.snps' --indels-all-sequences-filtered='/gscmnt/sata835/info/medseq/model_data/2852971605/build101625141/sam_snp_related_metrics/indels_all_sequences.filtered' --germline-bam-file='/gscmnt/sata835/info/medseq/model_data/2852971605/build101625141/alignments/101625141_merged_rmdup.bam' --data-directory=/gscmnt/sata424/info/medseq/Freimer-Boehnke/Germline_Pipeline_Test/

EOS
}

sub help_detail {
    my $self = shift;
    return <<"EOS"
This tool runs the capture germline pipeline to take in samtools SNPs and indels and a bam file. It results in running varscan, annotating, then outputting tiered SNPs and indels.
EOS
}

sub pre_execute {
    my $self = shift;

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

    # Default ref seq
    unless (defined $self->reference_fasta) {
        $self->reference_fasta("/gscmnt/839/info/medseq/reference_sequences/NCBI-human-build36/all_sequences.fa");
    }

    # Set (hardcoded) defaults for tools that have defaults that do not agree with somatic pipeline
    unless (defined $self->skip_if_output_present) {
        $self->skip_if_output_present(1);
    }
    unless (defined $self->only_tier_1) {
        $self->only_tier_1(0);
    }
    unless (defined $self->only_tier_1_indel) {
        $self->only_tier_1_indel(0);
    }

    return 1;
}

sub default_filenames{
    my $self = shift;
   
    my %default_filenames = (        
        ## samtools Adapted Files ##
        adaptor_output_indel                => 'samtools.output.indel.formatted',
        samtools_snp_output_adaptor         => 'samtools.output.snp.adaptor',

        ## VarScan Output Files ##
        varscan_snp_output                  => 'varScan.output.snp',
        varscan_indel_output                => 'varScan.output.indel',

        ## VarScan Adapted Output Files ##
        varscan_adaptor_snp                 => 'varScan.output.snp.formatted',
        varscan_adaptor_indel               => 'varScan.output.indel.formatted',

        ## Combined samtools+VarScan Output files ##
        merged_snp_output                   => 'merged.germline.snp',            ## Generated from merge-variants of samtools and varScan
        merged_indel_output                 => 'merged.germline.indel',          ## Generated from merge-variants of samtools and varScan ##

        ## Annotation output files ##
        annotate_output_snp                 => 'annotation.germline.snp.transcript',
        ucsc_output_snp                     => 'annotation.germline.snp.ucsc',
        ucsc_output_indel                   => 'annotation.germline.indel.ucsc',
        ucsc_unannotated_output             => 'annotation.germline.snp.unannot-ucsc',
        ucsc_unannotated_indel_output       => 'annotation.germline.indel.unannot-ucsc',
        annotate_output_indel               => 'annotation.germline.indel.transcript',

        ## Tiered SNP and indel files (all confidence) ##
        tier_1_snp_file                     => 'merged.germline.snp.tier1.out',
        tier_2_snp_file                     => 'merged.germline.snp.tier2.out',
        tier_3_snp_file                     => 'merged.germline.snp.tier3.out',
        tier_4_snp_file                     => 'merged.germline.snp.tier4.out',
        tier_1_indel_file                   => 'merged.germline.indel.tier1.out',
        tier_2_indel_file                   => 'merged.germline.indel.tier2.out',
        tier_3_indel_file                   => 'merged.germline.indel.tier3.out',
        tier_4_indel_file                   => 'merged.germline.indel.tier4.out',

        ## Other pipeline output files ##
        circos_graph                        => 'circos_graph.out',
        variant_report_output               => 'cancer_report.html', 
        file_summary_report_output          => 'file_summary_report.html',
    );

    return %default_filenames;
}

1;
__DATA__
<?xml version='1.0' standalone='yes'?>

<workflow name="Germline Pipeline" logDir="/gsc/var/log/genome/germline_capture_pipeline">

<!-- VARSCAN2 GERMLINE -->

<!--  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Varscan Germline" toProperty="skip_if_output_present" /> -->
  <link fromOperation="input connector" fromProperty="germline_bam_file" toOperation="Varscan Germline" toProperty="bam_file" />
  <link fromOperation="input connector" fromProperty="reference_fasta" toOperation="Varscan Germline" toProperty="reference" />
  <link fromOperation="input connector" fromProperty="varscan_snp_output" toOperation="Varscan Germline" toProperty="output_snp" />
  <link fromOperation="input connector" fromProperty="varscan_indel_output" toOperation="Varscan Germline" toProperty="output_indel" />

<!-- FORMAT VARSCAN SNPS/INDELS -->

  <link fromOperation="Varscan Germline" fromProperty="output_snp" toOperation="Format Varscan Snvs" toProperty="variants_file" />
  <link fromOperation="input connector" fromProperty="varscan_adaptor_snp" toOperation="Format Varscan Snvs" toProperty="output_file" />

  <link fromOperation="Varscan Germline" fromProperty="output_indel" toOperation="Format Varscan Indels" toProperty="variants_file" />
  <link fromOperation="input connector" fromProperty="varscan_adaptor_indel" toOperation="Format Varscan Indels" toProperty="output_file" />
  
<!-- FORMAT FILTERED SAMTOOLS SNPS -->

  <link fromOperation="input connector" fromProperty="filtered_indelpe_snps" toOperation="Format Samtools Snvs" toProperty="variants_file" />
  <link fromOperation="input connector" fromProperty="samtools_snp_output_adaptor" toOperation="Format Samtools Snvs" toProperty="output_file" />

<!-- MERGE FILTERED SAMTOOLS SNPS AND VARSCAN SNPS -->

  <link fromOperation="Format Varscan Snvs" fromProperty="output_file" toOperation="Merge SNPs" toProperty="varscan_file" />
  <link fromOperation="Format Samtools Snvs" fromProperty="output_file" toOperation="Merge SNPs" toProperty="glf_file" />
  <link fromOperation="input connector" fromProperty="merged_snp_output" toOperation="Merge SNPs" toProperty="output_file" />

<!-- RUN TRANSCRIPT ANNOTATION FOR SNPS --> 
  
  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Annotate Transcript Variants Snp" toProperty="skip_if_output_present" />
  <link fromOperation="Merge SNPs" fromProperty="output_file" toOperation="Annotate Transcript Variants Snp" toProperty="variant_file" />
  <link fromOperation="input connector" fromProperty="annotate_output_snp" toOperation="Annotate Transcript Variants Snp" toProperty="output_file" />
  <link fromOperation="input connector" fromProperty="annotate_no_headers" toOperation="Annotate Transcript Variants Snp" toProperty="no_headers" />
  <link fromOperation="input connector" fromProperty="transcript_annotation_filter" toOperation="Annotate Transcript Variants Snp" toProperty="annotation_filter" />

<!-- RUN UCSC ANNOTATION FOR SNPS --> 

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Annotate UCSC" toProperty="skip_if_output_present" />
  <link fromOperation="Merge SNPs" fromProperty="output_file" toOperation="Annotate UCSC" toProperty="input_file" />
  <link fromOperation="input connector" fromProperty="ucsc_output_snp" toOperation="Annotate UCSC" toProperty="output_file" /> 
  <link fromOperation="input connector" fromProperty="ucsc_unannotated_output" toOperation="Annotate UCSC" toProperty="unannotated_file" /> 
  <link fromOperation="input connector" fromProperty="only_tier_1" toOperation="Annotate UCSC" toProperty="skip" /> 

<!-- TIER VARIANTS -->

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Tier Variants Snp" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="tier_1_snp_file" toOperation="Tier Variants Snp" toProperty="tier1_file" />
  <link fromOperation="input connector" fromProperty="tier_2_snp_file" toOperation="Tier Variants Snp" toProperty="tier2_file" />
  <link fromOperation="input connector" fromProperty="tier_3_snp_file" toOperation="Tier Variants Snp" toProperty="tier3_file" />
  <link fromOperation="input connector" fromProperty="tier_4_snp_file" toOperation="Tier Variants Snp" toProperty="tier4_file" />
  <link fromOperation="input connector" fromProperty="only_tier_1" toOperation="Tier Variants Snp" toProperty="only_tier_1" />
  <link fromOperation="Annotate UCSC" fromProperty="output_file" toOperation="Tier Variants Snp" toProperty="ucsc_file" />
  <link fromOperation="input connector" fromProperty="filtered_indelpe_snps" toOperation="Tier Variants Snp" toProperty="variant_file" />
  <link fromOperation="Annotate Transcript Variants Snp" fromProperty="output_file" toOperation="Tier Variants Snp" toProperty="transcript_annotation_file" />

<!-- FORMAT SAMTOOLS INDELS -->

  <link fromOperation="input connector" fromProperty="indels_all_sequences_filtered" toOperation="Format Samtools Indels" toProperty="variants_file" />
  <link fromOperation="input connector" fromProperty="adaptor_output_indel" toOperation="Format Samtools Indels" toProperty="output_file" />

<!-- MERGE ADAPTED INDELS FROM SAMTOOLS AND VARSCAN -->

  <link fromOperation="Format Varscan Indels" fromProperty="output_file" toOperation="Merge Indels" toProperty="varscan_file" />
  <link fromOperation="Format Samtools Indels" fromProperty="output_file" toOperation="Merge Indels" toProperty="glf_file" />
  <link fromOperation="input connector" fromProperty="merged_indel_output" toOperation="Merge Indels" toProperty="output_file" />

<!-- RUN TRANSCRIPT ANNOTATION FOR INDELS -->

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Annotate Transcript Variants Indel" toProperty="skip_if_output_present" />
  <link fromOperation="Merge Indels" fromProperty="output_file" toOperation="Annotate Transcript Variants Indel" toProperty="variant_file" />
  <link fromOperation="input connector" fromProperty="annotate_output_indel" toOperation="Annotate Transcript Variants Indel" toProperty="output_file" />
  <link fromOperation="input connector" fromProperty="annotate_no_headers" toOperation="Annotate Transcript Variants Indel" toProperty="no_headers" />
  <link fromOperation="input connector" fromProperty="transcript_annotation_filter" toOperation="Annotate Transcript Variants Indel" toProperty="annotation_filter" />

<!-- RUN UCSC ANNOTATION FOR INDELS --> 

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Annotate UCSC Indel" toProperty="skip_if_output_present" />
  <link fromOperation="Merge Indels" fromProperty="output_file" toOperation="Annotate UCSC Indel" toProperty="input_file" />
  <link fromOperation="input connector" fromProperty="ucsc_output_indel" toOperation="Annotate UCSC Indel" toProperty="output_file" /> 
  <link fromOperation="input connector" fromProperty="ucsc_unannotated_indel_output" toOperation="Annotate UCSC Indel" toProperty="unannotated_file" /> 
  <link fromOperation="input connector" fromProperty="only_tier_1_indel" toOperation="Annotate UCSC Indel" toProperty="skip" /> 

<!-- TIER INDELS -->

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Tier Variants Indel" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="tier_1_indel_file" toOperation="Tier Variants Indel" toProperty="tier1_file" />
  <link fromOperation="input connector" fromProperty="tier_2_indel_file" toOperation="Tier Variants Indel" toProperty="tier2_file" />
  <link fromOperation="input connector" fromProperty="tier_3_indel_file" toOperation="Tier Variants Indel" toProperty="tier3_file" />
  <link fromOperation="input connector" fromProperty="tier_4_indel_file" toOperation="Tier Variants Indel" toProperty="tier4_file" />
  <link fromOperation="input connector" fromProperty="only_tier_1_indel" toOperation="Tier Variants Indel" toProperty="only_tier_1" />
  <link fromOperation="Annotate UCSC Indel" fromProperty="output_file" toOperation="Tier Variants Indel" toProperty="ucsc_file" />
  <link fromOperation="Merge Indels" fromProperty="output_file" toOperation="Tier Variants Indel" toProperty="variant_file" />
  <link fromOperation="Annotate Transcript Variants Indel" fromProperty="output_file" toOperation="Tier Variants Indel" toProperty="transcript_annotation_file" />

<!-- PLOT CIRCOS -->

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Plot Circos" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="circos_graph" toOperation="Plot Circos" toProperty="output_file" />
  <link fromOperation="Tier Variants Snp" fromProperty="tier1_file" toOperation="Plot Circos" toProperty="tier1_hclabel_file" />

<!-- WAIT FOR CIRCOS -->

  <link fromOperation="input connector" fromProperty="build_id" toOperation="Wait for Circos" toProperty="build_id" />
  <link fromOperation="Plot Circos" fromProperty="result" toOperation="Wait for Circos" toProperty="plot circos result" />

<!-- GENERATE REPORT -->
 
  <link fromOperation="Wait for Circos" fromProperty="build_id" toOperation="Generate Reports" toProperty="build_id" />
  <link fromOperation="input connector" fromProperty="variant_report_output" toOperation="Generate Reports" toProperty="variant_report_output" />
  <link fromOperation="input connector" fromProperty="file_summary_report_output" toOperation="Generate Reports" toProperty="file_summary_report_output" />
  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Generate Reports" toProperty="skip_if_output_present" />

<!-- OUTPUT CONNECTORS -->

  <link fromOperation="Plot Circos" fromProperty="output_file" toOperation="output connector" toProperty="circos_big_graph" />
  <link fromOperation="Generate Reports" fromProperty="variant_report_output" toOperation="output connector" toProperty="final_variant_report_output" />

  <link fromOperation="Tier Variants Snp" fromProperty="tier1_file" toOperation="output connector" toProperty="tier_1_snp" />
  <link fromOperation="Tier Variants Snp" fromProperty="tier2_file" toOperation="output connector" toProperty="tier_2_snp" />
  <link fromOperation="Tier Variants Snp" fromProperty="tier3_file" toOperation="output connector" toProperty="tier_3_snp" />
  <link fromOperation="Tier Variants Snp" fromProperty="tier4_file" toOperation="output connector" toProperty="tier_4_snp" />

  <link fromOperation="Tier Variants Indel" fromProperty="tier1_file" toOperation="output connector" toProperty="tier_1_indel_output" />
  <link fromOperation="Tier Variants Indel" fromProperty="tier2_file" toOperation="output connector" toProperty="tier_2_indel_output" />
  <link fromOperation="Tier Variants Indel" fromProperty="tier3_file" toOperation="output connector" toProperty="tier_3_indel_output" />
  <link fromOperation="Tier Variants Indel" fromProperty="tier4_file" toOperation="output connector" toProperty="tier_4_indel_output" />

  <operation name="Varscan Germline">
    <operationtype commandClass="Genome::Model::Tools::Varscan::Germline" typeClass="Workflow::OperationType::Command" />
  </operation>
  <operation name="Format Varscan Snvs">
    <operationtype commandClass="Genome::Model::Tools::Capture::FormatSnvs" typeClass="Workflow::OperationType::Command" />
  </operation>
  <operation name="Format Samtools Snvs">
    <operationtype commandClass="Genome::Model::Tools::Capture::FormatSnvs" typeClass="Workflow::OperationType::Command" />
  </operation>
  <operation name="Merge SNPs">
    <operationtype commandClass="Genome::Model::Tools::Capture::MergeVariantCalls" typeClass="Workflow::OperationType::Command" />
  </operation>  

  <operation name="Format Varscan Indels">
    <operationtype commandClass="Genome::Model::Tools::Capture::FormatIndels" typeClass="Workflow::OperationType::Command" />
  </operation>
  <operation name="Format Samtools Indels">
    <operationtype commandClass="Genome::Model::Tools::Capture::FormatIndels" typeClass="Workflow::OperationType::Command" />
  </operation>
  <operation name="Merge Indels">
    <operationtype commandClass="Genome::Model::Tools::Capture::MergeAdaptedIndels" typeClass="Workflow::OperationType::Command" />
  </operation>  

  <operation name="Annotate UCSC">
      <operationtype commandClass="Genome::Model::Tools::Somatic::UcscAnnotator" typeClass="Workflow::OperationType::Command" />
  </operation>
  <operation name="Annotate UCSC Indel">
      <operationtype commandClass="Genome::Model::Tools::Somatic::UcscAnnotator" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operation name="Annotate Transcript Variants Snp">
    <operationtype commandClass="Genome::Model::Tools::Annotate::TranscriptVariants" typeClass="Workflow::OperationType::Command" />
  </operation>
  <operation name="Annotate Transcript Variants Indel">
    <operationtype commandClass="Genome::Model::Tools::Annotate::TranscriptVariants" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operation name="Tier Variants Snp">
    <operationtype commandClass="Genome::Model::Tools::Somatic::TierVariants" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operation name="Tier Variants Indel">
    <operationtype commandClass="Genome::Model::Tools::Somatic::TierVariants" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operation name="Plot Circos">
    <operationtype commandClass="Genome::Model::Tools::Somatic::PlotCircos" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operation name="Wait for Circos">
      <operationtype typeClass="Workflow::OperationType::Block">
        <property>build_id</property>
        <property>plot circos result</property>
    </operationtype>
  </operation>

  <operation name="Generate Reports">
    <operationtype commandClass="Genome::Model::Tools::Somatic::RunReports" typeClass="Workflow::OperationType::Command" />
  </operation>  

  <operationtype typeClass="Workflow::OperationType::Model">
    <inputproperty>build_id</inputproperty>
    <inputproperty>filtered_indelpe_snps</inputproperty>
    <inputproperty>indels_all_sequences_filtered</inputproperty>

    <inputproperty isOptional="Y">germline_bam_file</inputproperty>   
    <inputproperty isOptional="Y">reference_fasta</inputproperty>

    <inputproperty isOptional="Y">samtools_snp_output_adaptor</inputproperty>
    <inputproperty isOptional="Y">adaptor_output_indel</inputproperty>

    <inputproperty isOptional="Y">skip_if_output_present</inputproperty>

    <inputproperty isOptional="Y">ucsc_output_snp</inputproperty>
    <inputproperty isOptional="Y">ucsc_output_indel</inputproperty>
    
    <inputproperty isOptional="Y">only_tier_1</inputproperty>
    <inputproperty isOptional="Y">only_tier_1_indel</inputproperty>

    <inputproperty isOptional="Y">data_directory</inputproperty>

    <inputproperty isOptional="Y">annotate_output_germline_snp</inputproperty>
    <inputproperty isOptional="Y">annotate_output_germline_indel</inputproperty>

    <inputproperty isOptional="Y">annotate_output_indel</inputproperty>
    <inputproperty isOptional="Y">annotate_output_snp</inputproperty>
    <inputproperty isOptional="Y">annotate_no_headers</inputproperty>
    <inputproperty isOptional="Y">transcript_annotation_filter</inputproperty>
    
    <inputproperty isOptional="Y">ucsc_unannotated_output</inputproperty>
    <inputproperty isOptional="Y">ucsc_unannotated_indel_output</inputproperty>

    <inputproperty isOptional="Y">varscan_snp_output</inputproperty>
    <inputproperty isOptional="Y">varscan_snp_germline</inputproperty>
    <inputproperty isOptional="Y">varscan_snp_loh</inputproperty>
    <inputproperty isOptional="Y">varscan_snp_germline</inputproperty>
    <inputproperty isOptional="Y">varscan_indel_output</inputproperty>
    <inputproperty isOptional="Y">varscan_indel_germline</inputproperty>
    <inputproperty isOptional="Y">varscan_indel_loh</inputproperty>
    <inputproperty isOptional="Y">varscan_indel_germline</inputproperty>
    <inputproperty isOptional="Y">varscan_adaptor_snp</inputproperty>
    <inputproperty isOptional="Y">varscan_adaptor_indel</inputproperty>

    <inputproperty isOptional="Y">merged_snp_output</inputproperty>
    <inputproperty isOptional="Y">merged_snp_output_novel</inputproperty>
    <inputproperty isOptional="Y">merged_indel_output</inputproperty>

    <inputproperty isOptional="Y">tier_1_snp_file</inputproperty>
    <inputproperty isOptional="Y">tier_2_snp_file</inputproperty>
    <inputproperty isOptional="Y">tier_3_snp_file</inputproperty>
    <inputproperty isOptional="Y">tier_4_snp_file</inputproperty>
    
    <inputproperty isOptional="Y">tier_1_indel_file</inputproperty>
    <inputproperty isOptional="Y">tier_2_indel_file</inputproperty>
    <inputproperty isOptional="Y">tier_3_indel_file</inputproperty>
    <inputproperty isOptional="Y">tier_4_indel_file</inputproperty>
   
    <inputproperty isOptional="Y">circos_graph</inputproperty>

    <inputproperty isOptional="Y">variant_report_output</inputproperty>
    <inputproperty isOptional="Y">file_summary_report_output</inputproperty>

    <outputproperty>tier_1_snp</outputproperty>
    <outputproperty>tier_2_snp</outputproperty>
    <outputproperty>tier_3_snp</outputproperty>
    <outputproperty>tier_4_snp</outputproperty>

    <outputproperty>tier_1_indel_output</outputproperty>
    <outputproperty>tier_2_indel_output</outputproperty>
    <outputproperty>tier_3_indel_output</outputproperty>
    <outputproperty>tier_4_indel_output</outputproperty>
    <outputproperty>circos_big_graph</outputproperty>
    <outputproperty>final_variant_report_output</outputproperty>
  </operationtype>

</workflow>


