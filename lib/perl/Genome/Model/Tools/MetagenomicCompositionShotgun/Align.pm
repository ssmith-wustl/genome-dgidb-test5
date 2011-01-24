package Genome::Model::Tools::MetagenomicCompositionShotgun::Align;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;

use Data::Dumper;

class Genome::Model::Tools::MetagenomicCompositionShotgun::Align{
    is  => ['Command'],
    has => [
        working_directory => {
            is  => 'String',
            is_input => '1',
            is_output => '1',
            doc => 'The working directory.',
        },
        reads_and_references => {
            is  => 'String',
            is_input => '1',
            doc => 'pipe delimited list of reads and ref seq files to align against',
        },
        aligned_file => {
            is  => 'String',
            is_output => '1',
            is_optional => '1',
            doc => 'The resulting alignment.',
        },
        unaligned_file => {
            is  => 'String',
            is_output => '1',
            is_optional => '1',
            doc => 'The resulting alignment.',
        },
        bwa_edit_distance=> {
            is => 'String',
            is_input => 1,
            doc => 'edit_distance param(-n) for bwa aligner (default value = .04)',
        },
        lsf_resource => {
                is_param => 1,
                value => "-R 'select[mem>8000 && model!=Opteron250 && type==LINUX64] span[hosts=1] rusage[mem=8000]' -M 8000000",
                #default_value => "-R 'select[mem>30000 && model!=Opteron250 && type==LINUX64] span[hosts=1] rusage[mem=30000]' -M 30000000",
        }

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
    $self->status_message(">>>Running Align at ".UR::Time->now);
    $self->status_message("Reads and reference: ".$self->reads_and_references);

    #split between reads and ref on @ sign...
    my @list = split(/\@/,$self->reads_and_references);

    my $reads_file = $list[0];
    my $reference_sequence = $list[1];
    
    #split between | on reads if paired end
    my $reads_basename;
    my @reads_list = split(/\|/,$reads_file);
    if ( scalar(@reads_list) == 2 ) {
    	my $name1 = File::Basename::basename($reads_list[0]);
    	my $name2 = File::Basename::basename($reads_list[1]);
    	$reads_basename = $name1."_paired_".$name2;
    } elsif ( scalar(@reads_list) == 1) {
    	$reads_basename = File::Basename::basename($reads_list[0]);
    } else {
    	$self->status_message("Found an invalid number of input read files.  Need 1 or 2. Quitting.");
    	return;
    }
    
    $self->status_message("Reads: ".$reads_file);
    $self->status_message("Reference: ".$reference_sequence);
    
    #my $refseq_basename = File::Basename::basename($reference_sequence);
    my @refseq_path_dirs = split(/\//,$reference_sequence);
    my $refseq_basename = $refseq_path_dirs[-2]; 
    
    #my $refseq_dirname = File::Basename::dirname($reference_sequence);
    #$self->status_message("Refseq directory: ".$refseq_dirname);
 
 	#switch here on all whether or not to generate a concise alignment only
    my $subdirectory = "alignments_top_hit";
    my $alignment_options = " -t4 ";
    $alignment_options .= "-n ".$self->bwa_edit_distance;
    my $alignment_file_name = "aligned.sam";
    my $top_hits = 1;
 	
 
    my $parent_directory = $self->working_directory."/$subdirectory/";
    my $working_directory = $self->working_directory."/$subdirectory/".$reads_basename."_aligned_against_".$refseq_basename;
    unless (-e $working_directory) {
    	Genome::Sys->create_directory("$working_directory");
    }
    
    #expected output files
    #Move these to resolver methods in a build object or something similar
    my $alignment_file = $working_directory."/".$alignment_file_name;
    my $aligner_output_file = $working_directory."/aligner_output.txt";
    my $unaligned_reads_file = $working_directory."/unaligned.txt";

    $self->unaligned_file($unaligned_reads_file);
    
    #check to see if those files exist
    my @expected_output_files = ( $aligner_output_file, $alignment_file );
    my $rv_check = Genome::Sys->are_files_ok(input_files=>\@expected_output_files);
    
    if (defined($rv_check)) {
	    if ($rv_check == 1) {
	    	#shortcut this step, all the required files exist.  Quit.
	    	$self->status_message("Skipping this step.  Alignments exist for reads file $reads_basename against reference sequence $refseq_basename. If you would like to regenerate these files, remove them and rerun.");
                $self->aligned_file($alignment_file);
    	        $self->working_directory($parent_directory);
    	        $self->status_message("<<<Completed alignment at ".UR::Time->now);
                return 1;
	    } 
    } 
 

    my $aligner;
    
    $reference_sequence =~ /^.*metagenome(\d).*$/;
    my $rg_tag = $1;

    $self->status_message("Adding read group tag: '$rg_tag'");

    $self->status_message("Aligning with standard options at ".UR::Time->now);
    $aligner = Genome::Model::Tools::Bwa::AlignReads->create(dna_type=>'dna', 
    								align_options=>$alignment_options, 
    								ref_seq_file=>$reference_sequence,
    								files_to_align_path=>$reads_file,
    								aligner_output_file=>$aligner_output_file,
                 						unaligned_reads_file=>$unaligned_reads_file,
    								alignment_file=>$alignment_file,
                                                                temp_directory=>$working_directory,
                                                                picard_conversion=>0,
                                                                sam_only=>1,
                                                                read_group_tag=>$rg_tag,
                                                                top_hits=>$top_hits,
            							);
    															
    $self->status_message("Aligning at ".UR::Time->now);
    my $rv_aligner = $aligner->execute;

    if ($rv_aligner != 1) {
              $self->error_message("Aligner failed.  Return value: $rv_aligner");
              return;
    }
   
    $self->aligned_file($alignment_file);
    $self->working_directory($parent_directory);
    Genome::Sys->mark_files_ok(input_files=>\@expected_output_files);
    
    $self->status_message("<<<Completed alignment at ".UR::Time->now);
    
    return 1;
}
1;
