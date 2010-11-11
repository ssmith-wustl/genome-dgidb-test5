package Genome::Model::Somatic::Command::Pindel;

use strict;
use warnings;

class Genome::Model::Somatic::Command::Pindel {
    is => ['Workflow::Operation::Command'],
    workflow => sub { Workflow::Operation->create_from_xml(\*DATA); }
};

sub help_brief {
    "Runs the pindel pipeline on the last complete build of a somatic model."
}

sub help_synopsis{
    my $self = shift;
    return <<"EOS"
genome model somatic pindel --model-id 123 --data-directory /someplace/for/output (do not put this in an allocated build directory, it will make allocations inaccurate)
EOS
}

sub help_detail {
    my $self = shift;
    return <<"EOS"
This tool runs the pindel pipeline on the last complete build of a somatic model. This pipeline will be integrated with the somatic pipeline in the future.
EOS
}

sub pre_execute {
    my $self = shift;

    # Obtain normal and tumor bams and check them. Either from somatic model id or from direct specification. 
    my ($build, $tumor_bam, $normal_bam);
    if ( ($self->model_id) && ($self->tumor_bam || $self->normal_bam) ) {
        $self->error_message("Usage error. Please specify either model_id OR tumor_bam and normal_bam, not both");
        die;
    } elsif ($self->model_id) {
        my $model = Genome::Model::Somatic->get($self->model_id);
        unless ($model) {
            $self->error_message("Could not get a somatic model for id " . $self->model_id);
            die;
        }

        $build = $model->last_succeeded_build;
        unless ($build) {
            $self->error_message("Could not get a last_succeeded_build for model id " . $self->model_id);
            die;
        }

        $normal_bam = $build->normal_build->whole_rmdup_bam_file;
        $tumor_bam = $build->tumor_build->whole_rmdup_bam_file;
    } elsif ($self->tumor_bam && $self->normal_bam) {
        $normal_bam = $self->normal_bam;
        $tumor_bam = $self->tumor_bam;
    } else {
        $self->error_message("Usage error. Please specify either model_id OR tumor_bam and normal_bam");
        die;
    }
    
    unless (-s $normal_bam) {
        $self->error_message("Normal bam $normal_bam does not exist or has 0 size");
        die;
    }

    unless (-s $tumor_bam) {
        $self->error_message("tumor bam $tumor_bam does not exist or has 0 size");
        die;
    }

    # Set default params
    unless ($self->annotate_no_headers) { $self->annotate_no_headers(1); }
    unless ($self->transcript_annotation_filter) { $self->transcript_annotation_filter("top"); }

    my %default_filenames = $self->default_filenames;
    for my $param (keys %default_filenames) {
        # set a default param if one has not been specified
        my $default_filename = $default_filenames{$param};
        $self->$param( join('/', $self->output_directory, $default_filename) );
    }

    # create directories
    for my $directory ( $self->assemble_t1n_dir, $self->assemble_t1t_dir, $self->assemble_t2n_dir, $self->assemble_t2t_dir, $self->assemble_t3n_dir, $self->assemble_t3t_dir) {
        unless ( Genome::Utility::FileSystem->create_directory($directory) ) {
            $self->error_message("Failed to create directory $directory");
            die;
        }
    }

    return 1;
}

sub default_filenames{
    my $self = shift;
   
    my %default_filenames = (
        annotation_output => "tier1_annotated.csv",
        intersect_output => "somatic_intersected.bed",
        assemble_t1n_dir => "assemble_tier1_normal/",
        assemble_t1t_dir => "assemble_tier1_tumor/",
        assemble_t2n_dir => "assemble_tier2_normal/",
        assemble_t2t_dir => "assemble_tier2_tumor/",
        assemble_t3n_dir => "assemble_tier3_normal/",
        assemble_t3t_dir => "assemble_tier3_tumor/",
        assemble_t1n_output => "assembled_normal.tier1",
        assemble_t1t_output => "assembled_tumor.tier1",
        assemble_t2n_output => "assembled_normal.tier2",
        assemble_t2t_output => "assembled_tumor.tier2",
        assemble_t3n_output => "assembled_normal.tier3",
        assemble_t3t_output => "assembled_tumor.tier3",
    );

    return %default_filenames;
}

1;
__DATA__
<?xml version='1.0' standalone='yes'?>

<workflow name="Pindel Assembly" logDir="/gsc/var/log/genome/pindel_assembly">

  <link fromOperation="input connector" fromProperty="normal_bam" toOperation="Pindel" toProperty="control_aligned_reads_input" />
  <link fromOperation="input connector" fromProperty="tumor_bam" toOperation="Pindel" toProperty="aligned_reads_input" />
  <link fromOperation="input connector" fromProperty="output_directory" toOperation="Pindel" toProperty="output_directory" />

  <link fromOperation="Pindel" fromProperty="indel_bed_output" toOperation="Pre-Assembly Tiering" toProperty="variant_file" />

  <link fromOperation="Pre-Assembly Tiering" fromProperty="tier1_output" toOperation="Assemble Tier 1 Normal" toProperty="indel_file" />
  <link fromOperation="input connector" fromProperty="normal_bam" toOperation="Assemble Tier 1 Normal" toProperty="bam_file" />
  <link fromOperation="input connector" fromProperty="assemble_t1n_dir" toOperation="Assemble Tier 1 Normal" toProperty="data_directory" />
  <link fromOperation="input connector" fromProperty="assemble_t1n_output" toOperation="Assemble Tier 1 Normal" toProperty="assembly_indel_list" />

  <link fromOperation="Pre-Assembly Tiering" fromProperty="tier1_output" toOperation="Assemble Tier 1 Tumor" toProperty="indel_file" />
  <link fromOperation="input connector" fromProperty="tumor_bam" toOperation="Assemble Tier 1 Tumor" toProperty="bam_file" />
  <link fromOperation="input connector" fromProperty="assemble_t1t_dir" toOperation="Assemble Tier 1 Tumor" toProperty="data_directory" />
  <link fromOperation="input connector" fromProperty="assemble_t1t_output" toOperation="Assemble Tier 1 Tumor" toProperty="assembly_indel_list" />

  <link fromOperation="Pre-Assembly Tiering" fromProperty="tier2_output" toOperation="Assemble Tier 2 Normal" toProperty="indel_file" />
  <link fromOperation="input connector" fromProperty="normal_bam" toOperation="Assemble Tier 2 Normal" toProperty="bam_file" />
  <link fromOperation="input connector" fromProperty="assemble_t2n_dir" toOperation="Assemble Tier 2 Normal" toProperty="data_directory" />
  <link fromOperation="input connector" fromProperty="assemble_t2n_output" toOperation="Assemble Tier 2 Normal" toProperty="assembly_indel_list" />

  <link fromOperation="Pre-Assembly Tiering" fromProperty="tier2_output" toOperation="Assemble Tier 2 Tumor" toProperty="indel_file" />
  <link fromOperation="input connector" fromProperty="tumor_bam" toOperation="Assemble Tier 2 Tumor" toProperty="bam_file" />
  <link fromOperation="input connector" fromProperty="assemble_t2t_dir" toOperation="Assemble Tier 2 Tumor" toProperty="data_directory" />
  <link fromOperation="input connector" fromProperty="assemble_t2t_output" toOperation="Assemble Tier 2 Tumor" toProperty="assembly_indel_list" />

  <link fromOperation="Pre-Assembly Tiering" fromProperty="tier3_output" toOperation="Assemble Tier 3 Normal" toProperty="indel_file" />
  <link fromOperation="input connector" fromProperty="normal_bam" toOperation="Assemble Tier 3 Normal" toProperty="bam_file" />
  <link fromOperation="input connector" fromProperty="assemble_t3n_dir" toOperation="Assemble Tier 3 Normal" toProperty="data_directory" />
  <link fromOperation="input connector" fromProperty="assemble_t3n_output" toOperation="Assemble Tier 3 Normal" toProperty="assembly_indel_list" />

  <link fromOperation="Pre-Assembly Tiering" fromProperty="tier3_output" toOperation="Assemble Tier 3 Tumor" toProperty="indel_file" />
  <link fromOperation="input connector" fromProperty="tumor_bam" toOperation="Assemble Tier 3 Tumor" toProperty="bam_file" />
  <link fromOperation="input connector" fromProperty="assemble_t3t_dir" toOperation="Assemble Tier 3 Tumor" toProperty="data_directory" />
  <link fromOperation="input connector" fromProperty="assemble_t3t_output" toOperation="Assemble Tier 3 Tumor" toProperty="assembly_indel_list" />

  <link fromOperation="Assemble Tier 1 Normal" fromProperty="assembly_indel_list" toOperation="Collect Normal Beds" toProperty="tier_1" />
  <link fromOperation="Assemble Tier 2 Normal" fromProperty="assembly_indel_list" toOperation="Collect Normal Beds" toProperty="tier_2" />
  <link fromOperation="Assemble Tier 3 Normal" fromProperty="assembly_indel_list" toOperation="Collect Normal Beds" toProperty="tier_3" />

  <link fromOperation="Assemble Tier 1 Tumor" fromProperty="assembly_indel_list" toOperation="Collect Tumor Beds" toProperty="tier_1" />
  <link fromOperation="Assemble Tier 2 Tumor" fromProperty="assembly_indel_list" toOperation="Collect Tumor Beds" toProperty="tier_2" />
  <link fromOperation="Assemble Tier 3 Tumor" fromProperty="assembly_indel_list" toOperation="Collect Tumor Beds" toProperty="tier_3" />

  <link fromOperation="Collect Normal Beds" fromProperty="output" toOperation="Intersect Indels" toProperty="normal_bed_file" />
  <link fromOperation="Collect Tumor Beds" fromProperty="output" toOperation="Intersect Indels" toProperty="tumor_bed_file" />
  <link fromOperation="input connector" fromProperty="intersect_output" toOperation="Intersect Indels" toProperty="somatic_file" />

  <link fromOperation="Intersect Indels" fromProperty="somatic_file" toOperation="Post-Assembly Tiering" toProperty="variant_file" />

  <link fromOperation="Post-Assembly Tiering" fromProperty="tier1_output" toOperation="Annotation" toProperty="variant_bed_file" />
  <link fromOperation="input connector" fromProperty="annotation_output" toOperation="Annotation" toProperty="output_file" />
  <link fromOperation="input connector" fromProperty="annotate_no_headers" toOperation="Annotation" toProperty="no_headers" />
  <link fromOperation="input connector" fromProperty="transcript_annotation_filter" toOperation="Annotation" toProperty="annotation_filter" />

  <link fromOperation="Annotation" fromProperty="output_file" toOperation="output connector" toProperty="output" />
  
  <operation name="Pindel">
    <operationtype commandClass="Genome::Model::Tools::DetectVariants::Somatic::Pindel" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operation name="Pre-Assembly Tiering">
    <operationtype commandClass="Genome::Model::Tools::Annotate::FastTier" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operation name="Assemble Tier 1 Normal">
    <operationtype commandClass="Genome::Model::Tools::Somatic::AssembleIndelBed" typeClass="Workflow::OperationType::Command" />
  </operation>
  <operation name="Assemble Tier 1 Tumor">
    <operationtype commandClass="Genome::Model::Tools::Somatic::AssembleIndelBed" typeClass="Workflow::OperationType::Command" />
  </operation>
  <operation name="Assemble Tier 2 Normal">
    <operationtype commandClass="Genome::Model::Tools::Somatic::AssembleIndelBed" typeClass="Workflow::OperationType::Command" />
  </operation>
  <operation name="Assemble Tier 2 Tumor">
    <operationtype commandClass="Genome::Model::Tools::Somatic::AssembleIndelBed" typeClass="Workflow::OperationType::Command" />
  </operation>
  <operation name="Assemble Tier 3 Normal">
    <operationtype commandClass="Genome::Model::Tools::Somatic::AssembleIndelBed" typeClass="Workflow::OperationType::Command" />
  </operation>
  <operation name="Assemble Tier 3 Tumor">
    <operationtype commandClass="Genome::Model::Tools::Somatic::AssembleIndelBed" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operation name="Collect Normal Beds">
      <operationtype typeClass="Workflow::OperationType::Converge">
        <inputproperty>tier_1</inputproperty>
        <inputproperty>tier_2</inputproperty>
        <inputproperty>tier_3</inputproperty>
        <outputproperty>output</outputproperty>
    </operationtype>
  </operation>

  <operation name="Collect Tumor Beds">
      <operationtype typeClass="Workflow::OperationType::Converge">
        <inputproperty>tier_1</inputproperty>
        <inputproperty>tier_2</inputproperty>
        <inputproperty>tier_3</inputproperty>
        <outputproperty>output</outputproperty>
    </operationtype>
  </operation>

  <operation name="Intersect Indels">
    <operationtype commandClass="Genome::Model::Tools::Bed::Somatic" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operation name="Post-Assembly Tiering">
    <operationtype commandClass="Genome::Model::Tools::Annotate::FastTier" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operation name="Annotation">
    <operationtype commandClass="Genome::Model::Tools::Annotate::TranscriptVariants" typeClass="Workflow::OperationType::Command" />
  </operation>
  
  <operationtype typeClass="Workflow::OperationType::Model">
    <inputproperty isOptional="Y">model_id</inputproperty>
    <inputproperty isOptional="Y">normal_bam</inputproperty>
    <inputproperty isOptional="Y">tumor_bam</inputproperty>
    <inputproperty isOptional="Y">output_directory</inputproperty>

    <inputproperty isOptional="Y">assemble_t1n_dir</inputproperty>
    <inputproperty isOptional="Y">assemble_t1t_dir</inputproperty>
    <inputproperty isOptional="Y">assemble_t2n_dir</inputproperty>
    <inputproperty isOptional="Y">assemble_t2t_dir</inputproperty>
    <inputproperty isOptional="Y">assemble_t3n_dir</inputproperty>
    <inputproperty isOptional="Y">assemble_t3t_dir</inputproperty>
    <inputproperty isOptional="Y">assemble_t1n_output</inputproperty>
    <inputproperty isOptional="Y">assemble_t1t_output</inputproperty>
    <inputproperty isOptional="Y">assemble_t2n_output</inputproperty>
    <inputproperty isOptional="Y">assemble_t2t_output</inputproperty>
    <inputproperty isOptional="Y">assemble_t3n_output</inputproperty>
    <inputproperty isOptional="Y">assemble_t3t_output</inputproperty>

    <inputproperty isOptional="Y">annotate_no_headers</inputproperty>
    <inputproperty isOptional="Y">transcript_annotation_filter</inputproperty>
    <inputproperty isOptional="Y">annotation_output</inputproperty>

    <inputproperty isOptional="Y">intersect_output</inputproperty>

    <outputproperty>output</outputproperty>
  </operationtype>

</workflow>
