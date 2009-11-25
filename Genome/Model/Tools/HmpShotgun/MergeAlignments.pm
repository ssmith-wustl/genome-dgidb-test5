package Genome::Model::Tools::HmpShotgun::MergeAlignments;

use strict;
use warnings;

use Genome;
use Workflow;
use IO::File;

class Genome::Model::Tools::HmpShotgun::MergeAlignments {
    is  => ['Command'],
    has => [
        working_directory => {
            is  => 'String',
            is_input => '1',
            doc => 'The working directory.',
        },
        alignment_files => {
        	is  => 'ARRAY',
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
    $self->status_message(">>>Running MergeAlignments at ".UR::Time->now);
    #my $model_id = $self->model_id;
    my $alignment_files_ref = $self->alignment_files;
    my @alignment_files = @$alignment_files_ref;
    
    my $working_directory = $self->working_directory."/alignments/";
    $self->status_message("Working directory: ".$working_directory);
    my $merged_file = $working_directory."/final.bam";
    my @expected_output_files = ($merged_file);
    
    my $rv_check = Genome::Utility::FileSystem->are_files_ok(input_files=>\@expected_output_files);
    
    if (defined($rv_check)) {
	    if ($rv_check == 1) {
	    	#shortcut this step, all the required files exist.  Quit.
	    	$self->status_message("Skipping this step.  If you would like to regenerate these files, remove them and rerun.");
	   	    $self->status_message("<<<Completed MergeAlignments at ".UR::Time->now);
	   	    return 1;
	    }
	}
	
	if (scalar(@alignment_files) == 0) {
		 $self->error_message("*** No files to merge.  Quitting.");
		 return;
	} elsif ( scalar(@alignment_files) == 1) {
		$self->status_message("Only one alignment file is present.  Not merging, only copying.");
		my $cp_cmd = "cp ".$alignment_files[0]." ".$merged_file;
		my $rv_cp = Genome::Utility::FileSystem->shellcmd(cmd=>$cp_cmd);
		if ($rv_cp != 1) {
			$self->error_message("<<<Failed MergeAligments. Copy failed.  Return value: $rv_cp");
			return;
		} 
	} else {
	    $self->status_message("Merging files: ".join("\n",@alignment_files) );
	    $self->status_message("Destination file: ".$merged_file);
	    my $merger = Genome::Model::Tools::Sam::Merge->create(files_to_merge=>\@alignment_files,
	    														merged_file=>$merged_file,
	    														is_sorted=>1,
	    													   );
	    													   
	    my $rv_merge = $merger->execute;													 
	    
	    if ($rv_merge != 1) {
	    	$self->error_message("<<<Failed MergeAlignments.  Return value: $rv_merge");
	    	return;
	    }
    
	}
    
    Genome::Utility::FileSystem->mark_files_ok(input_files=>\@expected_output_files);
    
    $self->aligned_file($merged_file);
    $self->status_message("<<<Completed MergeAlignments for testing at at ".UR::Time->now);
    return 1;
 
}
1;
