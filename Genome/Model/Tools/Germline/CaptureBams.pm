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
    unless (defined $self->only_tier_1) {
        $self->only_tier_1(0);
    }
    unless (defined $self->only_tier_1_indel) {
        $self->only_tier_1_indel(1);
    }

    return 1;
}

sub default_filenames{
    my $self = shift;
   
    my %default_filenames = (        
        filtered_indelpe_snps               => 'filtered.indelpe.snps',
        adapted_indel_file                  => 'adapted.indels',

        ## New annotation files for germline variants ##
        annotate_output_germline_snp        => 'annotation.germline.snp.transcript',
        annotate_output_germline_indel      => 'annotation.germline.indel.transcript',

        ## Tiered SNP and indel files (all confidence) ##
        tier_1_snp_file                     => 'merged.somatic.snp.tier1.out',
        tier_2_snp_file                     => 'merged.somatic.snp.tier2.out',
        tier_3_snp_file                     => 'merged.somatic.snp.tier3.out',
        tier_4_snp_file                     => 'merged.somatic.snp.tier4.out',
        tier_1_indel_file                   => 'merged.somatic.indel.tier1.out',

        ## New Germline Files ##
        tier_1_germline_snp_file            => 'merged.germline.snp.tier1.out',
        tier_1_germline_indel_file            => 'merged.germline.indel.tier1.out',

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
    
  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Tier Variants Snp" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="tier_1_snp_file" toOperation="Tier Variants Snp" toProperty="tier1_file" />
  <link fromOperation="input connector" fromProperty="tier_2_snp_file" toOperation="Tier Variants Snp" toProperty="tier2_file" />
  <link fromOperation="input connector" fromProperty="tier_3_snp_file" toOperation="Tier Variants Snp" toProperty="tier3_file" />
  <link fromOperation="input connector" fromProperty="tier_4_snp_file" toOperation="Tier Variants Snp" toProperty="tier4_file" />
  <link fromOperation="input connector" fromProperty="only_tier_1" toOperation="Tier Variants Snp" toProperty="only_tier_1" />
  <link fromOperation="input connector" fromProperty="ucsc_output" toOperation="Tier Variants Snp" toProperty="ucsc_file" />
  <link fromOperation="input connector" fromProperty="filtered_indelpe_snps" toOperation="Tier Variants Snp" toProperty="variant_file" />
  <link fromOperation="input connector" fromProperty="annotate_output_germline_snp" toOperation="Tier Variants Snp" toProperty="transcript_annotation_file" />

  <link fromOperation="Tier Variants Snp" fromProperty="tier1_file" toOperation="Upload Variants Snp Tier 1" toProperty="variant_file" />
  <link fromOperation="input connector" fromProperty="annotate_output_germline_snp" toOperation="Upload Variants Snp Tier 1" toProperty="annotation_file" />
  <link fromOperation="input connector" fromProperty="upload_variants_snp_1_output" toOperation="Upload Variants Snp Tier 1" toProperty="output_file" />
  <link fromOperation="input connector" fromProperty="build_id" toOperation="Upload Variants Snp Tier 1" toProperty="build_id" />

  <link fromOperation="Tier Variants Snp" fromProperty="tier2_file" toOperation="Upload Variants Snp Tier 2" toProperty="variant_file" />
  <link fromOperation="input connector" fromProperty="annotate_output_germline_snp" toOperation="Upload Variants Snp Tier 2" toProperty="annotation_file" />
  <link fromOperation="input connector" fromProperty="upload_variants_snp_2_output" toOperation="Upload Variants Snp Tier 2" toProperty="output_file" />
  <link fromOperation="input connector" fromProperty="build_id" toOperation="Upload Variants Snp Tier 2" toProperty="build_id" />
  <link fromOperation="input connector" fromProperty="only_tier_1" toOperation="Upload Variants Snp Tier 2" toProperty="_skip" />

  <link fromOperation="Upload Variants Snp Tier 1" fromProperty="output_file" toOperation="output connector" toProperty="tier_1_snp" />
  <link fromOperation="Upload Variants Snp Tier 2" fromProperty="output_file" toOperation="output connector" toProperty="tier_2_snp" />

  <link fromOperation="Tier Variants Snp" fromProperty="tier3_file" toOperation="output connector" toProperty="tier_3_snp" />
  <link fromOperation="Tier Variants Snp" fromProperty="tier4_file" toOperation="output connector" toProperty="tier_4_snp" />

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Tier Variants Indel" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="tier_1_indel_file" toOperation="Tier Variants Indel" toProperty="tier1_file" />
  <link fromOperation="input connector" fromProperty="only_tier_1_indel" toOperation="Tier Variants Indel" toProperty="only_tier_1" />
  <link fromOperation="input connector" fromProperty="adapted_indel_file" toOperation="Tier Variants Indel" toProperty="variant_file" />
  <link fromOperation="input connector" fromProperty="annotate_output_germline_indel" toOperation="Tier Variants Indel" toProperty="transcript_annotation_file" />

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Plot Circos" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="circos_graph" toOperation="Plot Circos" toProperty="output_file" />
  <link fromOperation="Upload Variants Snp Tier 1" fromProperty="output_file" toOperation="Plot Circos" toProperty="tier1_hclabel_file" />

  <link fromOperation="Tier Variants Indel" fromProperty="tier1_file" toOperation="Upload Variants Indel" toProperty="variant_file" />
  <link fromOperation="input connector" fromProperty="annotate_output_germline_indel" toOperation="Upload Variants Indel" toProperty="annotation_file" />
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

  <operation name="Tier Variants Snp">
    <operationtype commandClass="Genome::Model::Tools::Somatic::TierVariants" typeClass="Workflow::OperationType::Command" />
  </operation>
  <operation name="Upload Variants Snp Tier 1">
    <operationtype commandClass="Genome::Model::Tools::Somatic::UploadVariants" typeClass="Workflow::OperationType::Command" />
  </operation>
  <operation name="Upload Variants Snp Tier 2">
    <operationtype commandClass="Genome::Model::Tools::Somatic::UploadVariants" typeClass="Workflow::OperationType::Command" />
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
    <inputproperty>build_id</inputproperty>
    <inputproperty>filtered_indelpe_snps</inputproperty>
    <inputproperty>adapted_indel_file</inputproperty>
    
    <inputproperty isOptional="Y">skip_if_output_present</inputproperty>

    <inputproperty isOptional="Y">only_tier_1</inputproperty>
    <inputproperty isOptional="Y">only_tier_1_indel</inputproperty>

    <inputproperty isOptional="Y">data_directory</inputproperty>

    <inputproperty isOptional="Y">annotate_output_germline_snp</inputproperty>
    <inputproperty isOptional="Y">annotate_output_germline_indel</inputproperty>

    <inputproperty isOptional="Y">ucsc_output</inputproperty>

    <inputproperty isOptional="Y">tier_1_snp_file</inputproperty>
    <inputproperty isOptional="Y">tier_2_snp_file</inputproperty>
    <inputproperty isOptional="Y">tier_3_snp_file</inputproperty>
    <inputproperty isOptional="Y">tier_4_snp_file</inputproperty>

    <inputproperty isOptional="Y">upload_variants_snp_1_output</inputproperty>
    <inputproperty isOptional="Y">upload_variants_snp_2_output</inputproperty>
    <inputproperty isOptional="Y">upload_variants_indel_output</inputproperty>
    
    <inputproperty isOptional="Y">tier_1_indel_file</inputproperty>
   
    <inputproperty isOptional="Y">circos_graph</inputproperty>

    <inputproperty isOptional="Y">report_output</inputproperty>
    
    <outputproperty>tier_1_snp</outputproperty>
    <outputproperty>tier_2_snp</outputproperty>
    <outputproperty>tier_3_snp</outputproperty>
    <outputproperty>tier_4_snp</outputproperty>

    <outputproperty>tier_1_indel_output</outputproperty>
    <outputproperty>circos_big_graph</outputproperty>
    <outputproperty>final_report_output</outputproperty>
  </operationtype>

</workflow>


