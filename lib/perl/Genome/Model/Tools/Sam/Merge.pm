package Genome::Model::Tools::Sam::Merge;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;
use File::Basename;
use Sys::Hostname;
use Genome::Utility::AsyncFileSystem qw(on_each_line);

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
        is_sorted => {
            is  => 'Integer',
            doc => 'Denoting whether the input data is chrom position sorted (1/0)  Default 0',
            default_value => 0,
	        is_optional => 1
        },
        software => {
            is => 'Text',
            default_value => 'picard',
            valid_values => ['picard', 'samtools'],
            doc => 'the software tool to use for merging BAM files.  defualt_value=>picard',
        },
        bam_index => {
            is  => 'Boolean',
            doc => 'flag to create bam index or not',
            is_optional   => 1,
            default_value => 1,
        }
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

sub merge_command {
    my $self = shift;
    my @input_files = @_;

    my $merged_file = $self->merged_file;
    my $bam_merge_cmd;
    if ($self->software eq 'picard') {
        my $picard_path = $self->picard_path;
        my $bam_merge_tool = "java -Xmx2g -Dcom.sun.management.jmxremote -cp $picard_path/MergeSamFiles.jar net.sf.picard.sam.MergeSamFiles MSD=true SO=coordinate AS=true VALIDATION_STRINGENCY=SILENT O=$merged_file ";
        my $list_of_files = join(' I=',@input_files);
        $self->status_message('Files to merge: '. $list_of_files);
	$bam_merge_cmd = "$bam_merge_tool I=$list_of_files";
    } elsif ($self->software eq 'samtools') {
        my $sam_path = $self->samtools_path;
        my $bam_merge_tool = $sam_path .' merge ';
        my $list_of_files = join(' ',@input_files);
        $self->status_message("Files to merge: ". $list_of_files);
	$bam_merge_cmd = "$bam_merge_tool $merged_file $list_of_files";
    } else {
        die ('Failed to resolve merge command for software '. $self->software);
    }
    return $bam_merge_cmd
}


sub execute {
    my $self = shift;

    $self->dump_status_messages(1);
    $self->dump_error_messages(1);

    my @files = @{$self->files_to_merge};
    my $file_type = $self->file_type;  
    my $result = $self->merged_file; 
    
    $self->status_message("Attempting to merge: ". join(",",@files) );
    $self->status_message("Into file: ". $result);
   
    if (scalar(@files) == 0 ) {
        $self->error_message("No files to merge."); 
        return;
    }

    if (-s $result )  {
       $self->error_message("The target merged file already exists at: $result . Please remove this file and rerun to generate a new merged file.");
       return;
    }
    #merge those Bam files...BAM!!!
    my $now = UR::Time->now;
    $self->status_message(">>> Beginning Bam merge at $now.");
    my $sam_path = $self->samtools_path; 
    my $bam_index_tool = $sam_path.' index';

    if (scalar(@files) == 1) {
        $self->status_message("Only one input file has been provided.  Simply sorting the input file (if necessary) and dropping it at the requested target location.");
 	    if ($self->is_sorted) {
            my $cp_cmd = sprintf("cp %s %s", $files[0], $result);
            my $cp_rv = Genome::Utility::FileSystem->shellcmd(cmd=>$cp_cmd, input_files=>\@files, output_files=>[$result], skip_if_output_is_present=>0);
            if ($cp_rv != 1) {
                $self->error_message("Bam copy error.  Return value: $cp_rv");
                return;
            }
	    } 
        else {
            # samtools sort adds a ".bam" to the end so snap that off for the output file location passed into merge.
            my ($tgt_file) = $result =~ m/(.*?)\.bam$/;
            my $sam_sort_cmd = sprintf("%s sort %s %s", $self->samtools_path, $files[0],  $tgt_file);
            my $sam_sort_rv = Genome::Utility::FileSystem->shellcmd(cmd=>$sam_sort_cmd, input_files=>\@files, output_files=>[$result], skip_if_output_is_present=>0);
            if ($sam_sort_rv != 1) {
                $self->error_message("Bam sort error.  Return value $sam_sort_rv");
                return;
            }
        }
    } 
    else {
	    my @input_sorted_fhs;
	    my @input_files;
	    if (!$self->is_sorted) {
	        foreach my $input_file (@files) {
		        my $dirname = dirname($input_file);
		        print "Using $dirname\n";
	            my $tmpfile = File::Temp->new(DIR=>$dirname, SUFFIX => ".sort_tmp.bam" );
	            my ($tgt_file) = $tmpfile->filename =~ m/(.*?)\.bam$/;
	            my $sam_sort_cmd = sprintf("%s sort %s %s", $self->samtools_path, $input_file,  $tgt_file);
	            my $sam_sort_rv = Genome::Utility::FileSystem->shellcmd(cmd=>$sam_sort_cmd, input_files=>[$input_file], output_files=>[$tmpfile->filename], skip_if_output_is_present=>0);
	            if ($sam_sort_rv != 1) {
	           	    $self->error_message("Bam sort error.  Return value $sam_sort_rv");
	           	    return;
	            }
	            push @input_sorted_fhs, $tmpfile;   
            }
	        @input_files = map {$_->filename} @input_sorted_fhs;
        } 
        else {
	        @input_files = @files;
        }

        my $bam_merge_cmd = $self->merge_command(@input_files);
	    $self->status_message("Bam merge command: $bam_merge_cmd");

        my $bam_merge_rv;

        if ($self->software eq 'picard') {
            $bam_merge_rv = $self->monitor_shellcmd(
                {
                    cmd=>$bam_merge_cmd,
                    input_files=>\@input_files,
                    output_files=>[$result],
                    skip_if_output_is_present=>0
                },
                60,
                900
            );
        } else {
            $bam_merge_rv = Genome::Utility::FileSystem->shellcmd(
                cmd=>$bam_merge_cmd,
                input_files=>\@input_files,
                output_files=>[$result],
                skip_if_output_is_present=>0
            );
        }

 	    $self->status_message("Bam merge return value: $bam_merge_rv");
	    if ($bam_merge_rv != 1) {
		    $self->error_message("Bam merge error!  Return value: $bam_merge_rv");
	    } 
        else {
		#merging success
		    $self->status_message("Success.  Files merged to: $result");
	    }
    }

    if ($self->bam_index) {
        my $bam_index_rv;
        if (defined $result) {
            $self->status_message("Indexing file: $result");
            my $bam_index_cmd = $bam_index_tool ." ". $result;
            #$bam_index_rv = system($bam_index_cmd);
            $bam_index_rv = Genome::Utility::FileSystem->shellcmd(
                cmd          => $bam_index_cmd,
                input_files  => [$result],
                output_files => [$result.".bai"],
				skip_if_output_is_present => 0,
            );
            unless ($bam_index_rv == 1) {
                $self->error_message("Bam index error!  Return value: $bam_index_rv");
            } 
            else {
                #indexing success
                $self->status_message("Bam indexed successfully.");
            }
        }
        else {
            #no final file defined, something went wrong
            $self->error_message("Can't create index.  No merged file defined.");
        }
    }

    $now = UR::Time->now;
    $self->status_message("<<< Completing Bam merge at $now.");

 
    return 1;
}

sub monitor_shellcmd {
    my ($self,$shellcmd_args,$check_interval,$max_stdout_interval) = @_;

    my $cmd = $shellcmd_args->{cmd};
    my $last_update = time;
    my $pid;
    my $w;
    $w = AnyEvent->timer(
        interval => $check_interval,
        cb => sub {
            if ( time - $last_update >= $max_stdout_interval) {
                my $message = <<MESSAGE;
To whom it may concern,

This command:

$cmd

Has not produced output on STDOUT in at least $max_stdout_interval seconds.

Host: %s
Perl Pid: %s 
Java Pid: %s
LSF Job: %s
User: %s

This is the last warning you will receive about this process.
MESSAGE

                undef $w;
                my $from = '"' . __PACKAGE__ . sprintf('" <%s@genome.wustl.edu>', $ENV{USER});

                my @to = qw/eclark ssmith boberkfe jeldred abrummet/;
                my $to = join(', ', map { "$_\@genome.wustl.edu" } @to);
                my $subject = 'Slow bam merge happening right now';
                my $data = sprintf($message,
                    hostname,$$,$pid,$ENV{LSB_JOBID},$ENV{USER});

                my $msg = MIME::Lite->new(
                    From => $from,
                    To => $to,
                    Cc => 'apipe-run@genome.wustl.edu',
                    Subject => $subject,
                    Data => $data
                );
                $msg->send();
            }
        }
    );

    my $cv = Genome::Utility::AsyncFileSystem->shellcmd(
        %$shellcmd_args,
        '>' => on_each_line {
            $last_update = time;
            print $_[0] if defined $_[0];
        },
        '$$' => \$pid
    );
    $cv->cb(sub { undef $w });

    return $cv->recv;
}

1;
