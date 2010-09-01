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
            $combined_headers_hd_fh->print($line) if ($line =~ /^\@HD/);
            $combined_headers_sq_fh->print($line) if ($line =~ /^\@SQ/);
            $combined_headers_rg_fh->print($line) if ($line =~ /^\@RG/);
            $combined_headers_pg_fh->print($line) if ($line =~ /^\@PG/);
            $combined_headers_co_fh->print($line) if ($line =~ /^\@CO/);
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

    return $combined_headers_path;
}

sub fix_headers {
    my $self = shift;
    my $bam_file = shift;

    (my $base_file = $bam_file) =~ s/\.bam$//;
    my $sam_file = "$base_file.sam";
    my $tmp_sam_file = "$base_file.sam.tmp";
    my $sorted_bam = "$base_file.bam";
    my $unsorted_bam = "$base_file.unsorted.bam";
    my $missing_headers_bam = "$base_file\_missing_headers.bam";

    my $headers_file = $self->combine_headers();

    # backup original bam
    Genome::Utility::FileSystem->copy_file($bam_file, $missing_headers_bam);

    # convert bam to sam
    my $bam_to_sam = Genome::Model::Tools::Sam::BamToSam->create(bam_file => $bam_file, sam_file => $tmp_sam_file);
    unless($bam_to_sam->execute()) {
        $self->error_message("Failed to convert BAM to SAM ($bam_file).");
        die $self->error_message;
    }
    $self->error_message("Failed to remove old BAM file ($bam_file).") unless(unlink($bam_file));

    # strip off headers
    my $strip_headers_cmd = "sed -i -e '/^\@/d' $tmp_sam_file";
    my $strip_headers = Genome::Utility::FileSystem->shellcmd(
        cmd => $strip_headers_cmd,
        input_files => [$tmp_sam_file],
        output_files => [$tmp_sam_file],
        skip_if_output_is_present => 0,
    );
    unless ($strip_headers) {
        $self->error_message("Failed to strip off headers from SAM file ($tmp_sam_file)");
        die $self->error_message;
    }

    # inject new headers
    my $inject_headers = Genome::Utility::FileSystem->cat(input_files => [$headers_file, $tmp_sam_file], output_file => $sam_file);
    unless($inject_headers) {
        $self->error_message("Failed to inject headers into SAM file ($tmp_sam_file)");
        die $self->error_message;
    }
    $self->error_message("Failed to remove old SAM file ($tmp_sam_file).") unless(unlink($tmp_sam_file));

    # convert sam to bam
    my $sam_to_bam_cmd = "samtools view -b -S $sam_file -o $unsorted_bam";
    my $sam_to_bam = Genome::Utility::FileSystem->shellcmd(
        cmd => $sam_to_bam_cmd,
        input_files => [$sam_file],
        output_files => [$unsorted_bam],
    );
    unless($sam_to_bam) {
        $self->error_message("Failed to convert file to BAM, ($sam_file -> $unsorted_bam)");
        die $self->error_message;
    }
    $self->error_message("Failed to remove SAM file ($sam_file).") unless(unlink($sam_file));

    # validate only headers have changed, i.e. reads have not changed
    my $original_bam_content_md5 = `samtools view $missing_headers_bam | md5sum`;
    my $fixed_bam_content_md5 = `samtools view $unsorted_bam | md5sum`;
    unless($original_bam_content_md5 eq $fixed_bam_content_md5) {
        $self->error_message("$unsorted_bam reads appear to differ from $missing_headers_bam");
        die $self->error_message;
    }

    # sort bam
    my $bam_sort = Genome::Model::Tools::Sam::SortBam->create(file_name => $unsorted_bam, output_file => $sorted_bam);
    unless($bam_sort->execute()) {
        $self->error_message("Failed to sort BAM ($unsorted_bam -> $sorted_bam).");
        die $self->error_message;
    }

    # cleanup unused files
    $self->error_message("Failed to cleanup unused files ($missing_headers_bam, $unsorted_bam).") unless(unlink($missing_headers_bam, $unsorted_bam));

    return 1;
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
            $self->status_message("Success.  Files merged to: $result");
        }

        # Samtools only preserves headers from first bam in merge so we need to fix
        if ($self->software eq 'samtools') {
            $self->status_message("Fixing headers on $result.");
            my $perl_rv = $self->fix_headers($result);
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
