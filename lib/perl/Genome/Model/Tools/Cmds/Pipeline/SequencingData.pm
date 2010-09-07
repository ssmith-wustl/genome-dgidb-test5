package Genome::Model::Tools::Cmds::Pipeline::SequencingData;

use strict;
use warnings;

class Genome::Model::Tools::Cmds::Pipeline::SequencingData {
    is => ['Workflow::Operation::Command'],
    workflow => sub { Workflow::Operation->create_from_xml(\*DATA); }
};

sub help_brief {
    "Runs the cmds pipeline for sequencing data."
}

sub help_synopsis{
    my $self = shift;
    return <<"EOS"
gmt cmds pipeline sequencing-data --model-group-id 123 --data-directory /someplace/for/output
gmt cmds pipeline sequencing-data --model-ids "123 456 789" --data-directory /someplace/for/output
EOS
}

sub help_detail {
    my $self = shift;
    return <<"EOS"
This tool runs the cmds pipeline for sequencing data 
The only parameters that should be provided are --data-directory and either --model-group-id or --model-ids.
EOS
}

sub pre_execute {
    my $self = shift;

    # make sure either model group or model id list was provided
    unless($self->model_ids || $self->model_group) {
        $self->error_message("Either model_ids or model_group must be provided");
        die $self->error_message;
    }

    # Set the operation name so we can later easily access workflow properties by build id
    #$self->_operation->name($self->_operation->name . ' Build ' . $self->build_id); 

    my %default_filenames = $self->default_filenames;
    for my $param (keys %default_filenames) {
        # set a default param if one has not been specified
        my $default_filename = $self->data_directory . "/" . $default_filenames{$param};
        unless ($self->$param) {
            $self->status_message("Param $param was not provided... generated $default_filename as a default");
            $self->$param($default_filename);
        }
    }

    # Create directories that do not already exist
    for my $dir ($self->data_directory, $self->compile_cna_output_dir, $self->merge_output_dir, $self->region_output_dir) {
        unless (-d $dir) {
            $self->status_message("$dir does not exist... creating it.");
            Genome::Utility::FileSystem->create_directory($dir);
        }
    }

    # Default to 23 chromosomes (1-22, X)
    unless ($self->number_of_chromosomes) {
        $self->number_of_chromosomes(23);
    }

    $self->r_library("cmds_lib.R");
    $self->cmds_test_dir($self->data_directory . "/cmds_test");
    $self->construct_r_commands;

    return 1;
}

sub default_filenames{
    my $self = shift;
   
    my %default_filenames = (
        compile_cna_output_dir => "/compiled_cna_output/",
        merge_output_dir => "/merged_output/",
        region_output_dir => "/individual_region_output/",
        table_output => "table.out",
    );

    return %default_filenames;
}

sub construct_r_commands {
    my $self = shift;

    my @command_list;
    my $plot_dir = $self->data_directory . "/cmds_plot";
    my $test_dir = $self->data_directory . "/cmds_test";
    my $data_dir = $self->merge_output_dir;

    # We need to generate one command per chromosome file from merge... for now lets let the user/default decide how many chromosomes we have, rather than parsing every file in pre_execute
    for my $index (1..$self->number_of_chromosomes) {
        my $command = "cmds.focal.test(data.dir='$data_dir',wsize=30,wstep=1,analysis.ID='$index',chr.colname='CHR',pos.colname='POS',plot.dir='$plot_dir',result.dir='$test_dir');";
        push @command_list, $command;
    }

    unless (@command_list) {
        $self->error_message("Could not construct a command list for R, or unexpected number of commands constructed");
        die;
    }

    $self->r_commands(\@command_list);

    return 1;
}



1;
__DATA__
<?xml version='1.0' standalone='yes'?>

<workflow name="CMDS sequencing data pipeline" logDir="/gsc/var/log/genome/cmds_sequencing_data_pipeline">

  <link fromOperation="input connector" fromProperty="model_ids" toOperation="Compile Cna Output" toProperty="model_ids" />
  <link fromOperation="input connector" fromProperty="model_group" toOperation="Compile Cna Output" toProperty="model_group" />
  <link fromOperation="input connector" fromProperty="compile_cna_output_dir" toOperation="Compile Cna Output" toProperty="output_dir" />
  <link fromOperation="input connector" fromProperty="force" toOperation="Compile Cna Output" toProperty="force" />
  
  <link fromOperation="input connector" fromProperty="merge_output_dir" toOperation="Merge Cna Output By Chrom" toProperty="output_dir" />
  <link fromOperation="Compile Cna Output" fromProperty="output_dir" toOperation="Merge Cna Output By Chrom" toProperty="bam_to_cna_output_dir" />

  <link fromOperation="input connector" fromProperty="r_library" toOperation="begin inner workflow" toProperty="library" />
  <link fromOperation="Merge Cna Output By Chrom" fromProperty="result" toOperation="begin inner workflow" toProperty="merge_result" />
  
  <link fromOperation="input connector" fromProperty="r_commands" toOperation="Inner Workflow" toProperty="r_command" />
  <link fromOperation="begin inner workflow" fromProperty="library" toOperation="Inner Workflow" toProperty="library" />
  
  <link fromOperation="input connector" fromProperty="cmds_test_dir" toOperation="end inner workflow" toProperty="cmds_test_dir" />
  <link fromOperation="Inner Workflow" fromProperty="call_r_results" toOperation="end inner workflow" toProperty="workflow_result" />
  
  <link fromOperation="end inner workflow" fromProperty="cmds_test_dir" toOperation="Individual Region Calls" toProperty="cmds_test_dir" />
  <link fromOperation="Merge Cna Output By Chrom" fromProperty="output_dir" toOperation="Individual Region Calls" toProperty="cmds_input_data_dir" />
  <link fromOperation="input connector" fromProperty="region_output_dir" toOperation="Individual Region Calls" toProperty="output_dir" />

  <link fromOperation="Individual Region Calls" fromProperty="output_dir" toOperation="Create Output Table" toProperty="region_call_dir" />
  <link fromOperation="input connector" fromProperty="table_output" toOperation="Create Output Table" toProperty="output_file" />

  <link fromOperation="Create Output Table" fromProperty="output_file" toOperation="output connector" toProperty="final_output" />
  
  <operation name="Compile Cna Output">
    <operationtype commandClass="Genome::Model::Tools::Cmds::CompileCnaOutput" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operation name="Merge Cna Output By Chrom">
    <operationtype commandClass="Genome::Model::Tools::Cmds::MergeCnaOutputByChrom" typeClass="Workflow::OperationType::Command" />
  </operation>
  
  <operation name="Inner Workflow" parallelBy="r_command">
    <link fromOperation="input connector" fromProperty="r_command" toOperation="Call R" toProperty="command" />
    <link fromOperation="input connector" fromProperty="library" toOperation="Call R" toProperty="library" />
    <link fromOperation="Call R" fromProperty="result" toOperation="output connector" toProperty="call_r_results" />
    <operation name="Call R">
      <operationtype commandClass="Genome::Model::Tools::R::CallR" typeClass="Workflow::OperationType::Command" />
    </operation>
    <operationtype typeClass="Workflow::OperationType::Model">
      <inputproperty>r_command</inputproperty>
      <inputproperty>library</inputproperty>
      <outputproperty>call_r_results</outputproperty>
    </operationtype>
  </operation>

  <operation name="Individual Region Calls">
    <operationtype commandClass="Genome::Model::Tools::Cmds::IndividualRegionCalls" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operation name="Create Output Table">
    <operationtype commandClass="Genome::Model::Tools::Cmds::CreateOutputTable" typeClass="Workflow::OperationType::Command" />
  </operation>

  <operation name="begin inner workflow">
    <operationtype typeClass="Workflow::OperationType::Block">
      <property>library</property>
      <property>merge_result</property>
    </operationtype>
  </operation>

  <operation name="end inner workflow">
    <operationtype typeClass="Workflow::OperationType::Block">
      <property>cmds_test_dir</property>
      <property>workflow_result</property>
    </operationtype>
  </operation>

  <operationtype typeClass="Workflow::OperationType::Model">
    <inputproperty isOptional="Y">model_ids</inputproperty>
    <inputproperty isOptional="Y">model_group</inputproperty>
    <inputproperty isOptional="Y">number_of_chromosomes</inputproperty>
    <inputproperty isOptional="Y">compile_cna_output_dir</inputproperty>
    <inputproperty isOptional="Y">merge_output_dir</inputproperty>
    <inputproperty isOptional="Y">region_output_dir</inputproperty>
    <inputproperty isOptional="Y">table_output</inputproperty>
    <inputproperty isOptional="Y">r_commands</inputproperty>
    <inputproperty isOptional="Y">r_library</inputproperty>
    <inputproperty isOptional="Y">cmds_test_dir</inputproperty>
    <inputproperty isOptional="Y">force</inputproperty>
    <inputproperty>data_directory</inputproperty>
    <outputproperty>final_output</outputproperty>
  </operationtype>

</workflow>


