package Genome::Model::Tools::HmpShotgun::AlignMetagenomes;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;

class Genome::Model::Tools::HmpShotgun::AlignMetagenomes {
    is  => ['Command'],
    has => [
        working_directory => {
            is  => 'String',
            is_input => '1',
            doc => 'The working directory.',
        },
        reference_sequence_file => {
        	is  => 'String',
            is_input => '1',
            doc => 'The reference sequence.',
        },
        reads_file => {
        	is  => 'String',
            is_input => '1',
            doc => 'The reads to align.',
        },
        aligned_file => {
        	is  => 'String',
            is_output => '1',
            is_optional => '1',
            doc => 'The resulting alignment.',
        },
        
	],
    has_param => [
           lsf_resource => {
           default_value => 'select[model!=Opteron250 && type==LINUX64] rusage[mem=4000]',
           },
    ],
};

sub help_brief {
    'Align reads against a given metagenomic reference.';
}

sub help_detail {
    return <<EOS
    Align reads against a given metagenomic reference.
EOS
}

sub execute {
    my $self = shift;

    $self->dump_status_messages(1);
    $self->status_message(">>>Running AlignMetagenomes at ".UR::Time->now);
    #my $model_id = $self->model_id;
    $self->status_message("Ref seq: ".$self->reference_sequence_file);
    $self->status_message("Reads: ".$self->reads_file);
    
    my $working_directory = $self->working_directory."/alignments/";
    unless (-e $working_directory) {
    	Genome::Utility::FileSystem->create_directory("$working_directory");
    }
    
    #expected output files
    #Move these to resolver methods in a build object or something similar
    my $aligner_output_file = $working_directory."/aligner_output.txt";
    my $unaligned_reads_file = $working_directory."/unaligned.txt";
    my $alignment_file = $working_directory."/alignment_file.bam";
    my $alignment_file_index = $alignment_file.".bai";
    
    $self->aligned_file($alignment_file);
    
    #check to see if those files exist
    my @expected_output_files = ( $aligner_output_file, $unaligned_reads_file, $alignment_file, $alignment_file_index );
    my $rv_check = Genome::Utility::FileSystem->are_files_ok(input_files=>\@expected_output_files);
    
    if ($rv_check == 1) {
    	#shortcut this step, all the required files exist.  Quit.
    	$self->status_message("Skipping this step.  If you would like to regenerate these files, remove them and rerun.");
   	    $self->status_message("<<<Completed alignment at ".UR::Time->now);
   	    return 1;
    }
    
    my $aligner = Genome::Model::Tools::Bwa::AlignReads->create(dna_type=>'dna', 
    															align_options=>' -t 4 ', 
    															ref_seq_file=>$self->reference_sequence_file,
    															files_to_align_path=>$self->reads_file,
    															aligner_output_file=>$aligner_output_file,
    															unaligned_reads_file=>$unaligned_reads_file,
    															alignment_file=>$alignment_file,
    															);
    															
    $self->status_message("Aligning at ".UR::Time->now);
    my $rv_aligner = $aligner->execute;
   
    if ($rv_aligner == 1) {
    	Genome::Utility::FileSystem->mark_files_ok(input_files=>\@expected_output_files);
    }
    
    $self->status_message("<<<Completed alignment at ".UR::Time->now);
    
    return 1;
}
1;
