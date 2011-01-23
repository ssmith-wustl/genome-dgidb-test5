package Genome::Model::Tools::MetagenomicCompositionShotgun::Pipeline;

use strict;
use warnings;

use Genome;
use Workflow;

#run with
#gmt hmp-shotgun pipeline-multi --reads-files='/gscmnt/sata409/research/mmitreva/jpeck/testdata/t1.fna|/gscmnt/sata409/research/mmitreva/jpeck/testdata/t2.fna' --reference-sequences=/gscmnt/sata409/research/mmitreva/jpeck/refseq_metagenome1/all_sequences.fa,/gscmnt/sata409/research/mmitreva/jpeck/refseq_metagenome2/all_sequences.fa --working-directory=/gscmnt/sata409/research/mmitreva/jpeck/multi_build0 --workflow-log-directory=/gscmnt/sata409/research/mmitreva/jpeck/multi_build0/workflow_logs --regions-file=/gscmnt/sata409/research/mmitreva/jpeck/refseq_metagenome1/combined_ref_cov_regions.txt --reads-and-references=1 --generate-concise=1

class Genome::Model::Tools::MetagenomicCompositionShotgun::Pipeline {
    is => ['Workflow::Operation::Command'],
    workflow => sub { Workflow::Operation->create_from_xml(\*DATA); },
    has => [
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

    $self->status_message("Launching Metagenomic Composition Shotgun Pipeline");
    $self->status_message("--------------------------------------------------");
    $self->status_message("Creating required directories.");

    my $working_dir = $self->working_directory;
    my $log_dir = $working_dir."/logs";
    Genome::Sys->create_directory("$working_dir");
    Genome::Sys->create_directory("$working_dir/alignments_filtered");
    Genome::Sys->create_directory("$working_dir/alignments_top_hit");
    Genome::Sys->create_directory($log_dir);
    Genome::Sys->create_directory("$working_dir/tmp");
    Genome::Sys->create_directory("$working_dir/reports");
    $self->_operation->log_dir($log_dir);
  
    $self->status_message("Using working directory:".$working_dir);
    $self->status_message("Workflow log directory:".$log_dir);
    $self->status_message("Delete intermediate files on completion: ".$self->cleanup);
    
    $self->status_message("Reads file string: ".$self->reads_files);
    my @reads_files = split(/,/ , $self->reads_files);
    my $list_string = join("\n",@reads_files);
    $self->status_message("Reads files: \n".$list_string."\n"); 


    unless (-d $self->reference_directory){
        $self->error_message("Reference directory ".$self->reference_directory." does not exist!");
        die;
    }

    my $glob = $self->reference_directory."/".$self->reference_prefix;
    my @reference_sequences = <$glob*>;
    
    @reference_sequences = grep {-d $_} @reference_sequences; 
    unless (@reference_sequences){
        $self->error_message("No reference sequence dirs w/ prefix ". $self->reference_prefix." found in reference directory ". $self->reference_directory);
        die;
    }

    #for paired end, top hit alignments
    my @reads_and_references;
    for my $read_item (@reads_files) {
        for my $refseq_item (@reference_sequences) {
            push (@reads_and_references,$read_item."@".$refseq_item."/all_sequences.fa");
        }
    } 
   
    $self->status_message("Paired end Reads and References");
    $self->status_message(join("\n",@reads_and_references) );
    
    #$self->reads_file(\@reads_and_references);
    $self->reads_and_references(\@reads_and_references);
	
    $self->status_message("Pre-execute of Pipeline complete.");

    print Data::Dumper::Dumper $self->reads_and_references;

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

  <link fromOperation="input connector" fromProperty="working_directory"            toOperation="AlignTopHit" toProperty="working_directory" /> 
  <link fromOperation="input connector" fromProperty="reads_and_references"	        toOperation="AlignTopHit" toProperty="reads_and_references" />
  <link fromOperation="input connector" fromProperty="bwa_edit_distance"	        toOperation="AlignTopHit" toProperty="bwa_edit_distance" />
  <link fromOperation="AlignTopHit"     fromProperty="aligned_file"                 toOperation="MergeAlignments" toProperty="alignment_files" />
  <link fromOperation="AlignTopHit"     fromProperty="unaligned_file"               toOperation="MergeAlignments" toProperty="unaligned_files" />
  <link fromOperation="AlignTopHit"     fromProperty="working_directory"            toOperation="MergeAlignments" toProperty="working_directory" />

  <link fromOperation="MergeAlignments"	fromProperty="merged_aligned_file"          toOperation="FilterResults" toProperty="sam_input_file" />
   
  <link fromOperation="input connector" fromProperty="sam_header"	                toOperation="FilterResults" toProperty="sam_header_file" />
  <link fromOperation="input connector" fromProperty="working_directory"            toOperation="FilterResults" toProperty="working_directory" /> 
  <link fromOperation="input connector" fromProperty="taxonomy_file"                toOperation="FilterResults" toProperty="taxonomy_file" /> 
  <link fromOperation="input connector" fromProperty="viral_taxonomy_file"          toOperation="FilterResults" toProperty="viral_taxonomy_file" /> 
  <link fromOperation="input connector" fromProperty="mismatch_cutoff"	            toOperation="FilterResults" toProperty="mismatch_cutoff" />
  <link fromOperation="FilterResults"   fromProperty="bam_combined_output_file"     toOperation="RefCov" toProperty="aligned_bam_file" /> 
  <link fromOperation="FilterResults"   fromProperty="read_count_output_file"       toOperation="RefCov" toProperty="read_count_file" /> 

  <link fromOperation="input connector" fromProperty="working_directory"            toOperation="RefCov" toProperty="working_directory" /> 
  <link fromOperation="input connector" fromProperty="regions_file"                 toOperation="RefCov" toProperty="regions_file" /> 
  <link fromOperation="RefCov"          fromProperty="combined_file"                toOperation="Report" toProperty="align_final_file" /> 
  
  <link fromOperation="input connector" fromProperty="working_directory"            toOperation="Report" toProperty="working_directory" />
  <link fromOperation="Report"       	fromProperty="final_file"                   toOperation="output connector" toProperty="final_file" />

<operation name="AlignTopHit" parallelBy="reads_and_references">
    <operationtype commandClass="Genome::Model::Tools::MetagenomicCompositionShotgun::Align" typeClass="Workflow::OperationType::Command">
    </operationtype>
</operation>

<operation name="MergeAlignments">
    <operationtype commandClass="Genome::Model::Tools::MetagenomicCompositionShotgun::MergeAlignments" typeClass="Workflow::OperationType::Command" />
</operation>

<operation name="FilterResults">
    <operationtype commandClass="Genome::Model::Tools::MetagenomicCompositionShotgun::CombineAlignments" typeClass="Workflow::OperationType::Command" />
</operation>

<operation name="RefCov">
    <operationtype commandClass="Genome::Model::Tools::MetagenomicCompositionShotgun::RefCov" typeClass="Workflow::OperationType::Command" />
</operation>

<operation name="Report">
    <operationtype commandClass="Genome::Model::Tools::MetagenomicCompositionShotgun::Report" typeClass="Workflow::OperationType::Command" />
</operation>

<operationtype typeClass="Workflow::OperationType::Model">
    <inputproperty>working_directory</inputproperty>
    <inputproperty>reads_files</inputproperty>
    <inputproperty>reference_prefix</inputproperty>
    <inputproperty>reference_directory</inputproperty>
    <inputproperty>reads_and_references</inputproperty>
    <inputproperty>bwa_edit_distance</inputproperty>
    <inputproperty>mismatch_cutoff</inputproperty>
    <inputproperty>taxonomy_file</inputproperty>
    <inputproperty>viral_taxonomy_file</inputproperty>
    <inputproperty>regions_file</inputproperty>
    <inputproperty>sam_header</inputproperty>
    <outputproperty>final_file</outputproperty>

</operationtype>

</workflow>
