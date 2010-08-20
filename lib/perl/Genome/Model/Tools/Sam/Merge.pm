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
        },
        use_picard_version => {
            is => 'String',
            doc => 'version of picard to use if "picard" was used for the --software option',
            is_optional => 1,
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

sub merge_command {
    my $self = shift;
    my @input_files = @_;

    my $merged_file = $self->merged_file;
    my $bam_merge_cmd;
    if ($self->software eq 'picard') {
        $bam_merge_cmd = Genome::Model::Tools::Picard::MergeSamFiles->create(
            input_files => \@input_files, #file_type is determined automatically by picard
            output_file => $self->merged_file,
            use_version => $self->use_picard_version,

            #If $self->is_sorted is false, we sort before merging
            assume_sorted => 1,

            #Settings that have been hard-coded in this tool
            merge_sequence_dictionary => 1,
            sort_order => 'coordinate',
            validation_stringency => 'SILENT',
            maximum_memory => 2,
            additional_jvm_options => '-Dcom.sun.management.jmxremote', #for monitoring
            _monitor_command => 1,
            _monitor_mail_to => 'eclark ssmith boberkfe jeldred abrummet',
            _monitor_check_interval => 60, #seconds
            _monitor_stdout_interval => 900, #seconds
        );
        
        my $list_of_files = join(' ',@input_files);
        $self->status_message('Files to merge: '. $list_of_files);
    } elsif ($self->software eq 'samtools') {
        my $sam_path = $self->samtools_path;
        my $bam_merge_tool = "$sam_path merge";
        my $list_of_files = join(' ',@input_files);
        $self->status_message("Files to merge: ". $list_of_files);
	    $bam_merge_cmd = "$bam_merge_tool $merged_file $list_of_files";
    } else {
        die ('Failed to resolve merge command for software '. $self->software);
    }
    return $bam_merge_cmd
}


sub combine_headers {
    my $self = shift;
    my @files = @{$self->files_to_merge};

    my $time = time;
    $self->use_version('r613');

    my $tmp_dir = Genome::Utility::FileSystem->base_temp_directory;
    my $combined_headers_path = "$tmp_dir/$time\_combined_headers.sam";
    my $combined_headers_hd_fh = IO::File->new("> $combined_headers_path.hd") || die;
    my $combined_headers_sq_fh = IO::File->new("> $combined_headers_path.sq") || die;
    my $combined_headers_rg_fh = IO::File->new("> $combined_headers_path.rg") || die;
    my $combined_headers_pg_fh = IO::File->new("> $combined_headers_path.pg") || die;
    my $combined_headers_co_fh = IO::File->new("> $combined_headers_path.co") || die;

    # read in header lines of all type
    for my $file (@files) {
        my $header_fh = IO::File->new($self->samtools_path . " view -H $file |");
        while (my $line = $header_fh->getline) {
            print $combined_headers_hd_fh $line if ($line =~ /^\@HD/);
            print $combined_headers_sq_fh $line if ($line =~ /^\@SQ/);
            print $combined_headers_rg_fh $line if ($line =~ /^\@RG/);
            print $combined_headers_pg_fh $line if ($line =~ /^\@PG/);
            print $combined_headers_co_fh $line if ($line =~ /^\@CO/);
        }
    }

    $self->status_message("Finished splitting header files, beginning sort unique...\n");
    my @combined_header_files;
    push @combined_header_files, $self->unix_sort_unique("$combined_headers_path.hd");
    push @combined_header_files, $self->unix_sort_unique("$combined_headers_path.sq");
    push @combined_header_files, $self->unix_sort_unique("$combined_headers_path.rg");
    push @combined_header_files, $self->unix_sort_unique("$combined_headers_path.pg");
    push @combined_header_files, $self->unix_sort_unique("$combined_headers_path.co");

    my @sorted_files = @combined_header_files;
    @combined_header_files = ();
    for my $file (@sorted_files) {
        if (-s $file) {
            push @combined_header_files, $file;
        }
        else {
            (my $type = $file) =~ s/\.sorted\.uniq$//;
            $file =~ s/.*\.//;
            $self->status_message("Found empty " . uc($type) . " file."); 
        }
    }
    
    $self->status_message("\nCombining header segments into $combined_headers_path...\n");
    my $perl_rv = Genome::Utility::FileSystem->cat(
        input_files => \@combined_header_files,
        output_file => $combined_headers_path,
    );
    unless ($perl_rv) {
        $self->error_message("Failed to cat " . join(" ", @combined_header_files) . " > $combined_headers_path.");
        die $self->error_message;
    }

    #$self->status_message("\nReheadering alignment bams...\n");
    #my $sam_path = $self->samtools_path;
    #my $sam_tool = "$sam_path reheader";
    #my @reheadered_files;
    #for (my $i = 0; $i < @files; $i++) {
    #    my $file = $files[$i];
    #    my $tmp_file = "$tmp_dir/$time\_$i\_" . basename($file);
    #    my $perl_rv = Genome::Utility::FileSystem->shellcmd(cmd => "$sam_tool $combined_headers_path $file > $tmp_file", input_files => [$combined_headers_path, $file], output_files => [$tmp_file], skip_if_output_is_present => 0);
    #    if ($perl_rv) {
    #        push @reheadered_files, $tmp_file;
    #    }
    #    else {
    #        $self->error_message("Unable to reheader $file to $tmp_file.");
    #        die $self->error_message;
    #    }
    #}

    #return @reheadered_files;
    return $combined_headers_path;
}

sub unix_sort_unique {
    my ($self, $file) = @_;
    my $out_file = "$file.sorted.uniq";
    my $rv = system("sort -u $file -o $out_file");
    if ($rv) {
        $self->error_message("Failed to sort -u $file -o $out_file.");
        die $self->error_message;
    }
    return $out_file;
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
            $bam_merge_rv = $bam_merge_cmd->execute();
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

        # Samtools only preserves headers from first bam in merge so we'll fix
        if ($self->software eq 'samtools') {
            $self->status_message("Fixing headers on $result.");

            my $combined_headers_file = $self->combine_headers();

            my $perl_rv = rename($result, "$result\_missing_headers");
            if ($perl_rv) {
                $self->status_message("Renamed $result to $result\_missing_headers, creating $result with correct headers...");
            }
            else {
                $self->error_message("Failed to renamed $result to $result\_missing_headers.");
                die $self->error_message;
            }

            my $sam_path = $self->samtools_path;
            my $reheader_cmd = "$sam_path reheader $combined_headers_file $result\_missing_headers > $result";
            $perl_rv = Genome::Utility::FileSystem->shellcmd(
                cmd => $reheader_cmd,
                input_files => [$combined_headers_file],
                output_files => [$result],
                skip_if_output_is_present => 0,
            );
            if ($perl_rv) {
                $self->status_message("Fixed headers on $result.");
            }
            else {
                $self->error_message("Failed to fix headers on $result.");
            }

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

1;
