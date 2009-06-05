package Genome::Model::Tools::Sam::Merge;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;

class Genome::Model::Tools::Sam::Merge {
    is  => 'Genome::Model::Tools::Sam',
    has => [
        files_to_merge => {
            is  => 'List',
            doc => 'The bam files to merge ',
        },
        merged_file => {
            is  => 'String',
            doc => 'The resulting merged file',
        },
        file_type => {
            is  => 'String',
            doc => 'BAM or SAM.  Default is BAM.',
            default_value => 'BAM',
        },
    ],
};

sub help_brief {
    'Tool to merge BAM or SAM files';
}

sub help_detail {
    return <<EOS
    Tool to merge BAM or SAM files.
EOS
}



sub execute {
    my $self = shift;

    my @files = @{$self->files_to_merge};
    my $file_type = $self->file_type;  
    my $result = $self->merged_file; 
    
    $self->status_message("Attempting to merge: ". join(",",@files) );
    $self->status_message("Into file: ". $result);
   
    if (scalar(@files) == 0 ) {
        $self->error_message("No files to merge."); 
        return;
    }

    if (scalar(@files) == 1) {
       $self->status_message("Only one file has been provided.");
       return shift @files; 
    }
 
    if (-s $result )  {
       $self->error_message("The target merged file already exists at: $result . Please remove this file and rerun to generate a new merged file.");
       return;
    }
    
    #merge those Bam files...BAM!!!
    my $now = UR::Time->now;
    $self->status_message(">>> Beginning Bam merge at $now.");
    my $sam_path = $self->samtools_path;

    my $bam_merge_tool = $sam_path.' merge';
    my $bam_index_tool = $sam_path.' index';
  
    my $list_of_files = join(",",@files); 
    my $bam_merge_cmd = "$bam_merge_tool $result ".join(" ",@files);
    $self->status_message("Bam merge command: $bam_merge_cmd");
    
    my $bam_merge_rv = Genome::Utility::FileSystem->shellcmd(cmd=>$bam_merge_cmd,
                                                             input_files=>\@files,
                                                             output_files=>[$result],
                                                            );
    $self->status_message("Bam merge return value: $bam_merge_rv");
    if ($bam_merge_rv != 1) {
            $self->error_message("Bam merge error!  Return value: $bam_merge_rv");
    } else {
            #merging success
            $self->status_message("Success.  Files merged to: $result");
    }

    my $bam_index_rv;
    if (defined $result) {
        $self->status_message("Indexing file: $result");
        my $bam_index_cmd = $bam_index_tool ." ". $result;
        #$bam_index_rv = system($bam_index_cmd);
        $bam_index_rv = Genome::Utility::FileSystem->shellcmd(cmd=>$bam_index_cmd,
                                                              input_files=>[$result],
                                                              output_files=>[$result.".bai"],
                                                             );
        unless ($bam_index_rv == 1) {
                $self->error_message("Bam index error!  Return value: $bam_index_rv");
        } else {
                #indexing success
                $self->status_message("Bam indexed successfully.");
        }
    }  else {
        #no final file defined, something went wrong
        $self->error_message("Can't create index.  No merged file defined.");
    }

    $now = UR::Time->now;
    $self->status_message("<<< Completing Bam merge at $now.");

 
    return 1;
}


1;
