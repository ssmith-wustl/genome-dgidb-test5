package Genome::Model::Tools::MetagenomicCompositionShotgun::MergeAlignments;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;

class Genome::Model::Tools::MetagenomicCompositionShotgun::MergeAlignments {
    is  => ['Command'],
    has => [
        working_directory => {
            is  => 'ARRAY',
            is_input => '1',
            doc => 'The working directory.',
        },
        alignment_files => {
            is  => 'ARRAY',
            is_input => '1',
            doc => 'The reads to align.',
        },
        unaligned_files => {
        	is  => 'ARRAY',
            is_input => '1',
            doc => 'The unaligned files.',
        },
        merged_aligned_file => {
            is  => 'String',
            is_output => '1',
            is_optional => '1',
            doc => 'The resulting alignment.',
        },
         _working_directory => {
        	is  => 'String',
            is_optional => '1',
            doc => 'The resulting alignment.',
        },
        lsf_resource => {
                is_param => 1,
                value => "-R 'select[mem>8000 && model!=Opteron250 && type==LINUX64] span[hosts=1] rusage[mem=8000]' -M 8000000",
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
    $self->status_message(">>>Running MergeAlignments at ".UR::Time->now);
    #my $model_id = $self->model_id;
    my $alignment_files_ref = $self->alignment_files;
    my @alignment_files = @$alignment_files_ref;
    
    my $unaligned_files_ref = $self->unaligned_files;
    my @unaligned_files = @$unaligned_files_ref;
    
    #get parallelized inputs 
    #all of the alignment jobs are sending in the same working directory.  
    #pick the first one
    my $working_directory_ref = $self->working_directory;
    my @working_directory_list = @$working_directory_ref;
    my $working_directory = $working_directory_list[0];
    $self->_working_directory($working_directory);
    
    #my $working_directory = $self->working_directory."/alignments/";
    $self->status_message("Working directory: ".$working_directory);
    
    #first cat the unaligned reads, then the aligned files
    my $unaligned_combined = $working_directory."/unaligned_merged.sam";
    my $merged_alignment_unsorted = $working_directory."/aligned_merged_unsorted.sam";
    my @expected_output_files = ( $unaligned_combined, $merged_alignment_unsorted );
    my $rv_check = Genome::Utility::FileSystem->are_files_ok(input_files=>\@expected_output_files);
    #my $rv_unaligned_check = Genome::Utility::FileSystem->is_file_ok($unaligned_combined);
    if ($rv_check) {
    	$self->status_message("Output files exists.  Skipping the generation of the unaligned reads files and aligned merged unsorted file.  If you would like to regenerate these files, remove them and rerun.");  	
    } else {
    	my $rv_cat = Genome::Utility::FileSystem->cat(input_files=>\@unaligned_files,output_file=>$unaligned_combined);
    	if ($rv_cat) {
    		Genome::Utility::FileSystem->mark_file_ok($unaligned_combined);
    	} else {
    		$self->error_message("There was a problem generating the combined unaligned file: $unaligned_combined");
    		#may want to return here.
                return;
    	}

        if (scalar(@alignment_files) < 2) {
             $self->error_message("*** Invalid number of files to merge: ".scalar(@alignment_files).". Must have 2 or more.  Quitting.");
             return;
        } else {
    	    my $rv_merge = Genome::Utility::FileSystem->cat(input_files=>\@alignment_files,output_file=>$merged_alignment_unsorted);
            if ($rv_merge != 1) {
                    $self->error_message("<<<Failed MergeAlignments on cat merge.  Return value: $rv_merge");
                    return;
            }
            $self->status_message("Merge complete.");
   	    Genome::Utility::FileSystem->mark_file_ok($merged_alignment_unsorted);
        }

    }
   
    #sort alignment file 


    my $merged_alignment_sorted = $working_directory."/aligned_merged_sorted.sam";
    
    my @expected_sorted_output_files = ( $merged_alignment_sorted );
    $self->status_message("Starting sort step.  Checking on existence of $merged_alignment_sorted.");
    my $rv_sort_check = Genome::Utility::FileSystem->are_files_ok(input_files=>\@expected_sorted_output_files);
    
    if ($rv_sort_check == 1) {
        #shortcut this step, all the required files exist.  Quit.
        $self->merged_aligned_file($merged_alignment_sorted);
        $self->status_message("Skipping this step.  If you would like to regenerate these files, remove them and rerun.");
        $self->status_message("<<<Completed MergeAlignments at ".UR::Time->now);
        return 1;
    } else {

        my $tmp_dir = File::Temp::tempdir( DIR => $working_directory, CLEANUP => 1 );
        #sort
        #the 7G = 7Gigs of memory before writing to disk
        my $cmd_sorter = "sort -k 1 -T $tmp_dir -S 7G -o $merged_alignment_sorted $merged_alignment_unsorted";
        my $rv_sort = Genome::Utility::FileSystem->shellcmd(cmd=>$cmd_sorter);											 
        if ($rv_sort != 1) {
            $self->error_message("Sort failed.  Return value: $rv_sort");
            return;
        } else {
            $self->status_message("Sort complete.");
            unless (unlink $merged_alignment_unsorted){
                $self->warning_message("Failed to remove unsorted merged alignment file ". $merged_alignment_unsorted);
            }
            Genome::Utility::FileSystem->mark_files_ok(input_files=>\@expected_sorted_output_files);
            $self->merged_aligned_file($merged_alignment_sorted);
            $self->status_message("<<<Completed MergeAlignments for testing at at ".UR::Time->now);
            return 1;
        }
    }    
    
    return; 
}

sub resolve_name_sorted_file_name {
	my $self = shift;
	my $refseq_name = shift;
	my $extension = shift;
	return $self->_working_directory."/".$refseq_name."_name_sorted.".$extension;
}

1;
