package Genome::Model::Tools::HmpShotgun::Pipeline;

use strict;
use warnings;

use Genome;
use Workflow;

#to execute: 
#gt hmp-shotgun pipeline --model-id=1000 --reads-file=/gscmnt/temp206/info/seqana/species_independant/jpeck/testdata/reads.fna --reference-sequence-file=/gscmnt/temp206/info/seqana/species_independant/jpeck/refseq_test1/all_sequences.fa --working-directory=/gscmnt/temp206/info/seqana/species_independant/jpeck/build2 --regions-file=/gscmnt/temp206/info/seqana/species_independant/jpeck/refseq_test1/ref_cov_file.txt --workflow-log-directory=/gscmnt/temp206/info/seqana/species_independant/jpeck/wf_logs/

class Genome::Model::Tools::HmpShotgun::Pipeline {
    is => ['Workflow::Operation::Command'],
    workflow => sub { Workflow::Operation->create_from_xml(\*DATA); },
    has => [
        workflow_log_directory => {
                    is => 'String',
                    doc => 'The directory where the workflow logs (LSF output) should be dumped.' ,
        },
        cleanup => { 
                    is => 'Boolean',
                    is_optional => '1',
                    default_value => '0',
                    doc => 'A clean up flag.  Will remove intermediate files if set. Default = 0, no cleanup.',
        },
    ]
};

sub help_synopsis{
    my $self = shift;
    return "TBD";
}

sub pre_execute {
    my $self = shift;

    #make required directories if they don't exist
    my $working_dir = $self->working_directory;

    my $model_id = $self->model_id;

    $self->_operation->log_dir($self->workflow_log_directory);

    $self->status_message("Launching HMP Metagenomic Pipeline on model id:".$model_id);
    $self->status_message("Using working directory:".$working_dir);
    $self->status_message("Workflow log directory:".$self->workflow_log_directory);
    $self->status_message("Delete intermediate files on completion: ".$self->cleanup);
    $self->status_message("Creating required directories.");

    Genome::Utility::FileSystem->create_directory("$working_dir");
    Genome::Utility::FileSystem->create_directory("$working_dir/alignments");
    Genome::Utility::FileSystem->create_directory("$working_dir/metabalome");
    Genome::Utility::FileSystem->create_directory("$working_dir/pfam");
    Genome::Utility::FileSystem->create_directory("$working_dir/logs");
    Genome::Utility::FileSystem->create_directory("$working_dir/tmp");
    Genome::Utility::FileSystem->create_directory("$working_dir/blastx");
    Genome::Utility::FileSystem->create_directory("$working_dir/unaligned");
    Genome::Utility::FileSystem->create_directory("$working_dir/reports");

    $self->status_message("Pre-execute of Pipeline complete.");

    return 1;
}

sub post_execute {
    my $self = shift;
    my $working_dir = $self->working_directory;

    my $cleanup = $self->cleanup;

    if ($cleanup) {
        $self->status_message("Cleaning up intermediate files.");
     
    } else {
        $self->status_message("Leaving intermediate files behind.");
    }

	$self->status_message("Done.");
    return 1;
}

1;
__DATA__
<?xml version='1.0' standalone='yes'?>

<workflow name="HMP Metagenomic Pipeline">

  <link fromOperation="input connector" fromProperty="working_directory"            toOperation="Align" toProperty="working_directory" /> 
  <link fromOperation="input connector" fromProperty="reference_sequence_file"      toOperation="Align" toProperty="reference_sequence_file" />
  <link fromOperation="input connector" fromProperty="reads_file"				    toOperation="Align" toProperty="reads_file" />
  <link fromOperation="Align"           fromProperty="aligned_file"                 toOperation="RefCov" toProperty="aligned_bam_file" />
  
  <link fromOperation="input connector" fromProperty="working_directory"            toOperation="RefCov" toProperty="working_directory" /> 
  <link fromOperation="input connector" fromProperty="regions_file"                 toOperation="RefCov" toProperty="regions_file" /> 
  <link fromOperation="RefCov"          fromProperty="stats_file"                   toOperation="Report" toProperty="align_final_file" /> 
  
  <link fromOperation="input connector" fromProperty="model_id"                     toOperation="Metabolome" toProperty="model_id" />
  <link fromOperation="input connector" fromProperty="working_directory"            toOperation="Metabolome" toProperty="working_directory" /> 
  <link fromOperation="Metabolome"      fromProperty="final_file"                   toOperation="Report" toProperty="metabolome_final_file" />
  
  <link fromOperation="input connector" fromProperty="model_id"                     toOperation="Blastx" toProperty="model_id" />
  <link fromOperation="input connector" fromProperty="working_directory"            toOperation="Blastx" toProperty="working_directory" />
  <link fromOperation="Blastx"         	fromProperty="final_file"                   toOperation="Report" toProperty="blastx_final_file" />
  
  <link fromOperation="input connector" fromProperty="model_id"                     toOperation="Pfam" toProperty="model_id" />
  <link fromOperation="input connector" fromProperty="working_directory"            toOperation="Pfam" toProperty="working_directory" />
  <link fromOperation="Pfam"         	fromProperty="final_file"                   toOperation="Report" toProperty="pfam_final_file" />
  
  <link fromOperation="input connector" fromProperty="model_id"                     toOperation="Unaligned" toProperty="model_id" />
  <link fromOperation="input connector" fromProperty="working_directory"            toOperation="Unaligned" toProperty="working_directory" />
  <link fromOperation="Unaligned"       fromProperty="final_file"                   toOperation="Report" toProperty="unaligned_final_file" />
  
  <link fromOperation="input connector" fromProperty="model_id"                     toOperation="Report" toProperty="model_id" />
  <link fromOperation="input connector" fromProperty="working_directory"            toOperation="Report" toProperty="working_directory" />
  <link fromOperation="Report"       	fromProperty="final_file"                   toOperation="output connector" toProperty="final_file" />

<operation name="Align">
    <operationtype commandClass="Genome::Model::Tools::HmpShotgun::AlignMetagenomes" typeClass="Workflow::OperationType::Command" />
</operation>
<operation name="RefCov">
    <operationtype commandClass="Genome::Model::Tools::HmpShotgun::RefCov" typeClass="Workflow::OperationType::Command" />
</operation>
<operation name="Metabolome">
    <operationtype commandClass="Genome::Model::Tools::HmpShotgun::CoreMetabolome" typeClass="Workflow::OperationType::Command" />
</operation>
<operation name="Pfam">
    <operationtype commandClass="Genome::Model::Tools::HmpShotgun::Pfam" typeClass="Workflow::OperationType::Command" />
</operation>
<operation name="Blastx">
    <operationtype commandClass="Genome::Model::Tools::HmpShotgun::SpeciesBlastx" typeClass="Workflow::OperationType::Command" />
</operation>
<operation name="Unaligned">
    <operationtype commandClass="Genome::Model::Tools::HmpShotgun::UnalignedReadAnalysis" typeClass="Workflow::OperationType::Command" />
</operation>
<operation name="Report">
    <operationtype commandClass="Genome::Model::Tools::HmpShotgun::Report" typeClass="Workflow::OperationType::Command" />
</operation>

<operationtype typeClass="Workflow::OperationType::Model">
    <inputproperty>model_id</inputproperty>
    <inputproperty>working_directory</inputproperty>
    <inputproperty>reference_sequence_file</inputproperty>
    <inputproperty>reads_file</inputproperty>
    <inputproperty>regions_file</inputproperty>
    <outputproperty>final_file</outputproperty>
</operationtype>

</workflow>
