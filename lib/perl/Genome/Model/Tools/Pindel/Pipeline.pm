package Genome::Model::Tools::Pindel::Pipeline;

use strict;
use warnings;

class Genome::Model::Tools::Pindel::Pipeline {
    is => ['Workflow::Operation::Command'],
    workflow => sub { Workflow::Operation->create_from_xml(\*DATA); }
};

sub help_brief {
    "Runs the pindel workflow."
}

sub help_synopsis{
    my $self = shift;
    return <<"EOS"
gmt pindel pipeline --stuff
EOS
}

sub help_detail {
    my $self = shift;
    return <<"EOS"
This tool runs the pindel pipeline 
EOS
}

sub pre_execute {
    my $self = shift;

    # Set the operation name so we can later easily access workflow properties by build id
    #$self->_operation->name($self->_operation->name . ' Build ' . $self->build_id); 

    unless($self->skip_if_output_present) {
        $self->skip_if_output_present(1);
    }

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

    return 1;
}

sub default_filenames{
    my $self = shift;
   
    my %default_filenames = (
        dump_reads_single_output => "dumped_reads_single.csv",
        dump_reads_sw_output => "dumped_reads_sw.csv",
        sort_mate_output => "mate_sorted.csv",
        format_reads_sw_output => "formatted_sw_reads.csv",
        format_reads_one_end_output => "formatted_single_reads.csv",
        pindel_merged_reads => "merged_reads.csv",
        pindel_output_insertion => "one_end_insertions.csv",
        pindel_output_deletion => "one_end_deletions.csv",
        pindel_output_di => "one_end_di.csv",
        adaptor_insertion_output => "adapted_insertions.csv",
        adaptor_deletion_output => "adapted_deletions.csv",
    );

    return %default_filenames;
}


1;
__DATA__
<?xml version='1.0' standalone='yes'?>

<workflow name="Pindel Pipeline" logDir="/gsc/var/log/genome/pindel_pipeline">

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Dump Reads" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="bam_file" toOperation="Dump Reads" toProperty="bam_file" />
  <link fromOperation="input connector" fromProperty="dump_reads_single_output" toOperation="Dump Reads" toProperty="output_single_reads" />
  <link fromOperation="input connector" fromProperty="dump_reads_sw_output" toOperation="Dump Reads" toProperty="output_sw_reads" />

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Sort Mate" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="sort_mate_output" toOperation="Sort Mate" toProperty="output_file" />
  <link fromOperation="Dump Reads" fromProperty="output_single_reads" toOperation="Sort Mate" toProperty="unsorted_dumped_reads" />

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Format Reads" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="format_reads_sw_output" toOperation="Format Reads" toProperty="output_file_sw" />
  <link fromOperation="input connector" fromProperty="format_reads_one_end_output" toOperation="Format Reads" toProperty="output_file_one_end" />
  <link fromOperation="input connector" fromProperty="format_reads_tag" toOperation="Format Reads" toProperty="tag" />
  <link fromOperation="Dump Reads" fromProperty="output_sw_reads" toOperation="Format Reads" toProperty="sw_reads" />
  <link fromOperation="Sort Mate" fromProperty="output_file" toOperation="Format Reads" toProperty="one_end_reads" />

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Run Pindel" toProperty="skip_if_output_present" />
  <link fromOperation="input connector" fromProperty="pindel_output_insertion" toOperation="Run Pindel" toProperty="output_insertion" />
  <link fromOperation="input connector" fromProperty="pindel_output_deletion" toOperation="Run Pindel" toProperty="output_deletion" />
  <link fromOperation="input connector" fromProperty="pindel_output_di" toOperation="Run Pindel" toProperty="output_di" />
  <link fromOperation="input connector" fromProperty="model_id" toOperation="Run Pindel" toProperty="model_id" />
  <link fromOperation="input connector" fromProperty="pindel_merged_reads" toOperation="Run Pindel" toProperty="reads_file_merged" />
  <link fromOperation="Format Reads" fromProperty="output_file_sw" toOperation="Run Pindel" toProperty="reads_file_sw" />
  <link fromOperation="Format Reads" fromProperty="output_file_one_end" toOperation="Run Pindel" toProperty="reads_file_one_end" />

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Adapt Output Insertion" toProperty="skip_if_output_present" />
  <link fromOperation="Run Pindel" fromProperty="output_insertion" toOperation="Adapt Output Insertion" toProperty="input_file" />
  <link fromOperation="input connector" fromProperty="adaptor_insertion_output" toOperation="Adapt Output Insertion" toProperty="output_file" />

  <link fromOperation="input connector" fromProperty="skip_if_output_present" toOperation="Adapt Output Deletion" toProperty="skip_if_output_present" />
  <link fromOperation="Run Pindel" fromProperty="output_deletion" toOperation="Adapt Output Deletion" toProperty="input_file" />
  <link fromOperation="input connector" fromProperty="adaptor_deletion_output" toOperation="Adapt Output Deletion" toProperty="output_file" />

  <link fromOperation="Adapt Output Insertion" fromProperty="output_file" toOperation="output connector" toProperty="final_output_insertion" />
  <link fromOperation="Adapt Output Deletion" fromProperty="output_file" toOperation="output connector" toProperty="final_output_deletion" />
  
  <operation name="Dump Reads">
    <operationtype commandClass="Genome::Model::Tools::Pindel::DumpReads" typeClass="Workflow::OperationType::Command" />
  </operation>
  <operation name="Sort Mate">
    <operationtype commandClass="Genome::Model::Tools::Pindel::SortMate" typeClass="Workflow::OperationType::Command" />
  </operation>
  <operation name="Format Reads">
    <operationtype commandClass="Genome::Model::Tools::Pindel::FormatReads" typeClass="Workflow::OperationType::Command" />
  </operation>
  <operation name="Run Pindel">
    <operationtype commandClass="Genome::Model::Tools::Pindel::RunPindel" typeClass="Workflow::OperationType::Command" />
  </operation>
  <operation name="Adapt Output Insertion">
    <operationtype commandClass="Genome::Model::Tools::Annotate::Adaptor::Pindel" typeClass="Workflow::OperationType::Command" />
  </operation>
  <operation name="Adapt Output Deletion">
    <operationtype commandClass="Genome::Model::Tools::Annotate::Adaptor::Pindel" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operationtype typeClass="Workflow::OperationType::Model">
    <inputproperty>bam_file</inputproperty>
    <inputproperty>format_reads_tag</inputproperty>
    <inputproperty>data_directory</inputproperty>
    <inputproperty>model_id</inputproperty>

    <inputproperty isOptional="Y">skip_if_output_present</inputproperty>
    <inputproperty isOptional="Y">dump_reads_single_output</inputproperty>
    <inputproperty isOptional="Y">dump_reads_sw_output</inputproperty>

    <inputproperty isOptional="Y">sort_mate_output</inputproperty>

    <inputproperty isOptional="Y">format_reads_sw_output</inputproperty>
    <inputproperty isOptional="Y">format_reads_one_end_output</inputproperty>
    
    <inputproperty isOptional="Y">pindel_merged_reads</inputproperty>
    <inputproperty isOptional="Y">pindel_output_insertion</inputproperty>
    <inputproperty isOptional="Y">pindel_output_deletion</inputproperty>
    <inputproperty isOptional="Y">pindel_output_di</inputproperty>

    <inputproperty isOptional="Y">adaptor_insertion_output</inputproperty>
    <inputproperty isOptional="Y">adaptor_deletion_output</inputproperty>

    <outputproperty>final_output_insertion</outputproperty>
    <outputproperty>final_output_deletion</outputproperty>
  </operationtype>

</workflow>


