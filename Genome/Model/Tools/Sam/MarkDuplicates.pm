package Genome::Model::Tools::Sam::MarkDuplicates;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;
use File::Basename;

class Genome::Model::Tools::Sam::MarkDuplicates {
    is  => 'Genome::Model::Tools::Sam',
    has => [
        file_to_mark => {
            is  => 'String',
            doc => 'The bam file to mark ',
        },
        marked_file => {
            is  => 'String',
            doc => 'The resulting marked file',
        },
        metrics_file => {
            is  => 'String',
            doc => 'The resulting metrics file with deduplication statistics',
        },
        remove_duplicates => {
            is  => 'Integer',
            doc => 'Denoting whether the output file should have duplicates removed.  Default is 1, duplicates will be removed.',
            default_value => 1,
	    is_optional => 1
        },
        max_jvm_heap_size => {
            is  => 'Integer',
            doc => 'The size in gigabytes of the Java Virtual Machine maximum memory allocation.',
            default_value => 2,
	    is_optional => 1,
        },
        assume_sorted => {
            is  => 'Integer',
            doc => 'Assume the input file is coordinate order sorted.  Default is 1, true.',
	    default_value => 1,
	    is_optional => 1,
        },
        log_file => {
            is  => 'String',
            doc => 'The stdout of the mark duplicates tool',
	    is_optional => 1
        },
        tmp_dir => {
            is  => 'String',
            doc => 'The temporary working directory.  Provide this if you are marking duplicates on a whole genome bam file.',
	    is_optional => 1
        },


    ],
};

sub help_brief {
    'Tool to mark or remove duplicates from BAM or SAM files.';
}

sub help_detail {
    return <<EOS
    Tool to mark or remove duplicates from BAM or SAM files.
EOS
}

sub execute {
    my $self = shift;

    my $input_file = $self->file_to_mark;
    my $result = $self->marked_file; 
    
    $self->status_message("Attempting to mark duplicates." );
   
    unless (-e $input_file)  {
       $self->error_message("Source file $input_file not found!");
       return;
    }
    
    if (-e $result )  {
       $self->error_message("The target file already exists at: $result . Please remove this file and rerun to generate a new merged file.");
       return;
    }
    
    #merge those Bam files...BAM!!!
    my $now = UR::Time->now;
    $self->status_message(">>> Beginning mark duplicates at $now");
    my $picard_path = $self->picard_path;
    #This is a temporary fix until release 1.04
    my $mark_duplicates_jar = $picard_path."/MarkDuplicates.jar";
    my $classpath = "$mark_duplicates_jar";

    my $rm_option = 'true';
    if ($self->remove_duplicates ne '1') {
        $rm_option = 'false';
    }

    my $log_file_param;
    if (defined($self->log_file) ) {
        $log_file_param = ">> ".$self->log_file;
    }
    
    my $tmp_dir_param;
    if (defined($self->tmp_dir) ) {
        $tmp_dir_param = " tmp_dir=".$self->tmp_dir;
    }

    my $assume_sorted_param = 'true';
    if ($self->assume_sorted ne '1') {
        $assume_sorted_param = 'false';
    }
    
    my $mark_duplicates_cmd = "java -Xmx".$self->max_jvm_heap_size."g -cp $classpath net.sf.picard.sam.MarkDuplicates VALIDATION_STRINGENCY=SILENT metrics_file=".$self->metrics_file." I=$input_file O=$result remove_duplicates=$rm_option assume_sorted=$assume_sorted_param $tmp_dir_param $log_file_param";  

	$self->status_message("Picard mark duplicates command: $mark_duplicates_cmd");
	
	my $md_rv = Genome::Utility::FileSystem->shellcmd(
        cmd                         => $mark_duplicates_cmd,
        input_files                 => [$input_file],
        output_files                => [$result],
        skip_if_output_is_present   => 0,
    );

	$self->status_message("Mark duplicates return value: $md_rv");
	if ($md_rv != 1) {
		$self->error_message("Mark duplicates error!  Return value: $md_rv");
	} else {
		#merging success
		$self->status_message("Success.  Duplicates marked in file: $result");
	}

    $now = UR::Time->now;
    $self->status_message("<<< Completing mark duplicates at $now.");

 
    return 1;
}


1;
