package Genome::InstrumentData::AlignmentResult::Brat;

use strict;
use warnings;
use IO::File;
use File::Basename;
use File::Copy;
use Genome;

#  So, you want to build an aligner?  Follow these steps.
#
#  1) set aligner name in the UR class def
#  2) set required_rusage
#  3) Implement run_aligner
#  4) Implement aligner_params_for_sam_header
#
#  You also will want to create a Genome::InstrumentData::Command::Align::YOURCLASSHERE
#  so you can align from the command line too!

class Genome::InstrumentData::AlignmentResult::Brat {
    is => 'Genome::InstrumentData::AlignmentResult',
    has_constant => [
        aligner_name => { value => 'brat', is_param=>1 }
    ]
};

sub required_arch_os { 'x86_64' }

# LSF resources required to run the alignment.
#"-R 'select[model!=Opteron250 && type==LINUX64 && mem>16000 ** tmp > 150000] span[hosts=1] rusage[tmp=150000, mem=16000]' -M 16000000 -n 1";
sub required_rusage {
    "-R 'select[type==LINUX64 && mem>16000 && tmp > 100000] span[hosts=1] rusage[tmp=100000, mem=16000]' -M 16000000 -n 1";
}

#
#  Implement this method with the actual logic to run your aligner.
#  The pathnames for input files are passed in.
#
#  The expected output is an "all_sequences.sam" file in the scratch directory.
#  YOU MUST APPEND TO THIS FILE, NOT OVERWRITE.  This is because the calling code
#  may run multiple passes of run_aligner.  For example, when running trimming,
#  there may be two invocations - one with paired data, and one with a set of remaining
#  singleton reads whose mates were clipped too far in to be usable.
#
#  The sam file also needs to NOT have any SAM headers (i.e. lines starting with "@").
#  The pipeline adds its own detailed headers that are appropriate to the data.
#  Having headers here already will cause issues in the pipeline
#  downstream with picard merge.
#

sub _run_aligner {
    my $self = shift;
    my @input_pathnames = @_;

    # get refseq info and fasta files
    my $reference_build = $self->reference_build;
    my $reference_fasta_path = $reference_build->full_consensus_path('fa');
    # example dir /gscmnt/gc4096/info/model_data/2741951221/build101947881

    # get the index directory
    my $reference_index = $self->get_reference_sequence_index();
    my $reference_index_directory = $reference_index->data_dir();
    # example dir /gscmnt/sata921/info/medseq/cmiller/methylSeq/bratIndex

    # This is your scratch directory.  Whatever you put here will be wiped when the alignment
    # job exits.
    my $scratch_directory = $self->temp_scratch_directory;

    # This is the alignment output directory.  Whatever you put here will be synced up to the
    # final alignment directory that gets a disk allocation.
    my $staging_directory = $self->temp_staging_directory;

    # This is the SAM file you should be appending to.  Dont forget, no headers!
    my $sam_file = $scratch_directory . "/all_sequences.sam";
    # import format
    my $import_format = $self->instrument_data->import_format;

    # decompose aligner params for each stage of alignment
    my %aligner_params = $self->decomposed_aligner_params;

    # get the command path
    my $brat_cmd_path = dirname(Genome::Model::Tools::Brat->path_for_brat_version($self->aligner_version)) . "/";

    # Data is single-ended or paired-ended: key off the number of files passed in (1=SE, 2=PE)
    # Under no circumstances should you ever get more than 2 files, if you do then that's bad and
    # you should die.
    my $paired_end = 0;

    my $min_insert_size = -1;
    my $max_insert_size = -1;

    if (@input_pathnames == 1) {
        $self->status_message("_run_aligner called in single-ended mode.");
    } elsif (@input_pathnames == 2) {
        $self->status_message("_run_aligner called in paired-end mode.");
        $paired_end = 1;

        # get the instrument-data so we can calculate the minimum and maximum insert size
        # TODO this may be completely wrong... we'll see
        my $instrument_data = $self->instrument_data();
        my $median_insert_size = $instrument_data->median_insert_size();
        my $sd_above_insert_size = $instrument_data->sd_above_insert_size();
        my $sd_below_insert_size = $instrument_data->sd_below_insert_size();

        # TODO first pass... so we're within 2 standard deviations of the median?
        $min_insert_size = $median_insert_size - (2*$sd_below_insert_size); # TODO or should this also be above???
        $max_insert_size = $median_insert_size + (2*$sd_above_insert_size);

        #die("paired end data requires insert size params - not implemented yet (talk to Chris M.)");
        #my $min_insert_size = $self->min_insert_size;	
        #my $max_insert_size = $self->max_insert_size;
        if ($max_insert_size == -1) {
            die $self->error_message("Maximum insert size required for paired end data");
        }
    } else {
        die $self->error_message("_run_aligner called with " . scalar @input_pathnames . " files.  It should only get 1 or 2!");
    }


    ## Something like this goes back in once we get caching of individual fasta
    ## files set up on the blades
    ##
    ##    #get the reference directory path
    ##    print "ref_fasta_path: $reference_fasta_path\n";
    ##    my $ref_dir = dirname($reference_fasta_path);
    ##    print "ref_dir: $ref_dir\n";

    # find all the individual reference fastas and load them into an array
    # we'll keep a list with all references files for now
    #opendir(DIR, $reference_directory) or die $!;
    #while (my $filename = readdir(DIR)) {
    #    # if the filename matches this regex, output it to the list
    #    # should match 1.fa - 22.fa, along with X.fa, x.fa, Y.fa, y.fa
    #    # XXX will fail on contigs (NT_113956.fa) or other formats (chr22.fa)
    #    if ($filename =~ /^(([1-2]?[0-9])|([XYxy]))\.fa$/) {
    #        #my $cur_ref_file = $reference_directory . "/" . $filename;
    #        push @all_ref_files, "$reference_directory/$filename";
    #        #$ref_fh->print($cur_ref_file . "\n");
    #    }
    #}
    #closedir(DIR) or die $!;

    # Brat uses the concept of "list" files. List files are plain text files that contain a list of required input files.
    # For instance, brat's remove-dupl command requests a single plain-text file that lists all files of aligned reads to dedup.
    # If the output of our alignment step is bratout.dat, then the corresponding list file would contain a single line that has
    # the full path to bratout.dat. Yes, this is really redundant, especially when we only have a single output file.
    my %list_files;
    
    # When creating reference fastas split by contig, we also created a file listing each fasta file.
    # We load this file, get out the filenames, and prefix the correct directory.
    my $reference_fasta_list_fh = IO::File->new("< $reference_index_directory/reference_fasta_list.txt");
    my @reference_fastas = map{sprintf("%s/%s",$reference_index_directory,$_)} grep(!/^$/, split("\n", <$reference_fasta_list_fh>));
    $reference_fasta_list_fh->close();

    $DB::single = 1;
    print Data::Dumper::Dumper(@reference_fastas); # TODO verify that this whole thing is correct

    ## Note that we use the -P option with a pre-built index for alignment, but we still
    ## need the fastas for the acgt count step.
    $list_files{'reference_fastas'} = _create_temporary_list_file(@reference_fastas);

    # Create the list of expected index files, too.
    my @index_files = map{
            my $filename = basename($_);
            map{ sprintf("%s/%s.%s",$reference_index_directory,$filename,$_) } qw(bg hs ht);
        } @reference_fastas;
    push @index_files, "INFO.txt";



    ###################################################
    # Trim reads. This must be done first. The command follows this syntax:
    #   /gscmnt/sata921/info/medseq/cmiller/methylSeq/bratMod/trim -q 20 -m 2 -P $scratch_directory/trimmed
    ###################################################
    ###-------
    ### This shouldn't be necessary right now - defaults work fine
    ##
    ##    #determine which type of quality score we're using:
    ##    if ($import_format eq "solexa fastq") {
    ##	#older format - starts at ASCII 33
    ##	$trim_cmd = $trim_cmd . " -L 33";
    ##    } elsif ($import_format eq "illumina fastq") {
    ##	#newer format - starts at ASCII 64
    ##	$trim_cmd = $trim_cmd . " -L 64";
    ##    }
    ###----------
    $self->status_message("Trimming reads.");

    # make a prefix for trim files
    my $trim_prefix = $scratch_directory . "/trimmed";

    # output files consist of the following filenames prefixed with $trim_prefix
    my @trimmed_files = map{sprintf("%s_%s",$trim_prefix,$_)} $paired_end ?
        qw(reads1.txt reads2.txt mates1.txt mates2.txt mates1.seq mates2.seq pair1.fastq pair2.fastq err1.seq err2.seq badMate1.seq badMate2.seq) :
        qw(reads1.txt mates1.txt mates1.seq pair1.fastq err1.seq);
    
    # we need list files of mates for remove-dupl
    if ($paired_end) { # TODO should something happen when not running in paired end mode? look at documentation for remove-dupl i think...
        $list_files{'mates1'} = _create_temporary_list_file(grep(/.+\/mates1\.txt$/, @trimmed_files));
        $list_files{'mates2'} = _create_temporary_list_file(grep(/.+\/mates2\.txt$/, @trimmed_files));
    }

    # define the trim command and run it
    my $trim_cmd = sprintf("%s %s -P %s %s",
        $brat_cmd_path . "trim",
        $aligner_params{'trim_options'}, # -q 20 and -m 2
        $trim_prefix,
        $paired_end ?
            "-1 $input_pathnames[0] -2 $input_pathnames[1]" : 
            "-s $input_pathnames[0]"
    );

    my $rv = Genome::Sys->shellcmd(
        cmd => $trim_cmd,
        input_files => [@input_pathnames],
        output_files => [@trimmed_files]
    );
    unless($rv) { die $self->error_message("Trimming failed."); }




    ###################################################
    # run the read mapping
    # XXX everything after this point assumes that we work with a single output from the aligner
    ###################################################
    $self->status_message("Performing alignment.");
    
    # the file for aligned reads
    my @aligned_reads = ($scratch_directory . "/bratout.dat");
    
    # we need a list file for remove-dupl
    $list_files{'aligned_reads'} = _create_temporary_list_file(@aligned_reads);

    # uses precomputed index; alternatively you could do something like -r $list_files{'reference_fastas'} instead of -P $reference_index_dir
    my $align_cmd = sprintf("%s -P %s %s -o %s %s",
        $brat_cmd_path . "brat-large",
        $reference_index_directory,
        $paired_end ?
            "-1 $trimmed_files[0] -2 $trimmed_files[1] -pe -i $min_insert_size -a $max_insert_size" :
            "-s $trimmed_files[0]",
        $aligned_reads[0],
        $aligner_params{'align_options'} # -m 10 (number of mismatches) -bs (bisulfite option) -S (faster, at the expense of more mem)
    );

    $rv = Genome::Sys->shellcmd(
        cmd => $align_cmd,
        input_files => [@trimmed_files, @index_files],
        output_files => [@aligned_reads]
    );
    unless($rv) { die $self->error_message("Alignment failed."); }




    ###################################################
    # deduplicate reads
    ###################################################
    $self->status_message("Deduplicating reads.");    

    # for every file of aligned reads, have one that is deduped
    # once again, we must create a file that lists these .nodupl files
    my @deduped_reads = map{$_ . ".nodupl"} @aligned_reads;
    
    # we need a list file for acgt-count
    $list_files{'deduped_reads'} = _create_temporary_list_file(@deduped_reads);

    my $dedup_cmd = sprintf("%s -r %s %s",
        $brat_cmd_path . "remove-dupl",
        $list_files{'reference_fastas'}, # reference fastas.
        $paired_end ?
            "-p $list_files{'aligned_reads'} -1 $list_files{'mates1'} -2 $list_files{'mates2'}" : # TODO or is it just -p?
            "-s $list_files{'aligned_reads'}"
    );

    $rv = Genome::Sys->shellcmd(
        cmd => $dedup_cmd,
        input_files => [
            @reference_fastas, $list_files{'reference_fastas'},
            @aligned_reads, $list_files{'aligned_reads'},
            $trimmed_files[2], $list_files{'mates1'},
            $trimmed_files[3], $list_files{'mates2'}],
        output_files => [@deduped_reads]
    );
    unless($rv) { die $self->error_message("Deduping failed."); }




    ###################################################
    # sort reads
    ###################################################
    $self->status_message("Sorting reads.");

    my @sorted_deduped_reads = map{$_ . ".sorted"} @deduped_reads;

    my $sort_cmd = "sort -nk1 $deduped_reads[0] >$sorted_deduped_reads[0]";

    $rv = Genome::Sys->shellcmd(
        cmd => $sort_cmd,
        input_files => [@deduped_reads],
        output_files => [@sorted_deduped_reads]
    );
    unless($rv) { die $self->error_message("Sorting deduped files failed."); }




    ###################################################
    # convert to sam format
    ###################################################
    $self->status_message("Converting output to SAM format.");

    my $temp_sam_output = "$scratch_directory/mapped_reads.sam";
    # TODO not all files that this is using are passed in as parameters
    $self->_convert_reads_to_sam($paired_end, $sorted_deduped_reads[0], $temp_sam_output, $trim_prefix);




    ###################################################
    # sort sam file and append to all_sequences.sam
    ###################################################
    $self->status_message("Sorting SAM file and appending to all_sequences.sam.");

    my $append_cmd = "sort -nk 1 $temp_sam_output >> $sam_file";

    $rv = Genome::Sys->shellcmd(
        cmd => $append_cmd,
        input_files => [$temp_sam_output],
        output_files => [$sam_file]
    );
    unless($rv) { die $self->error_message("Sorting temporary sam file and appending to all_sequences.sam failed."); }

    ##for testing - copy the output so I can look at it
    ##system("cp $scratch_directory/* /gscmnt/sata921/info/medseq/cmiller/methylSeq/tmp/scratch1/");
    ##system("cp $refs_file /gscmnt/sata921/info/medseq/cmiller/methylSeq/tmp/scratch1/");




    ###################################################
    # create the methylation map
    ###################################################
    $self->status_message("Creating methylation map.");

    my $count_prefix = $staging_directory . "/map";
    
    my @counted_reads = ();

    if ($aligner_params{'count_options'} =~ /-B/) {
        @counted_reads = map{sprintf("%s_%s.txt",$count_prefix,$_)} qw(forw rev);
    } else {
        die $self->error_message("Unimplemented: acgt-count should be run with the -B option.");
        # TODO?
        # if the user doesn't use the -B switch, acgt-count creates a count of every base instead of a methylation map
        # in this case, acgt-count outputs $prefix_forw_refname and $prefix_rev_refname for every reference file
        # the following code creates this list of output files:
        #@counted_reads = map{
        #        my $filename = basename($_);
        #        # TODO confirm that the following is the actual output filename format; move code below suggests otherwise
        #        map{ sprintf("%s_%s_%s",$count_prefix,$_,$filename) } qw(forw rev);
        #    } @reference_fastas;
    }

    my $count_cmd = sprintf("%s -r %s -P %s %s",
        $brat_cmd_path . "acgt-count",
        $list_files{'reference_fastas'},
        $count_prefix,
        $paired_end ?
            "-p $list_files{'deduped_reads'}" :
            "-s $list_files{'deduped_reads'}", # TODO might be very wrong; manual says we might need to use -1 -2 instead of -p
        $aligner_params{'count_options'} # -B (get a map of methylation events, not a count of every base)
    );

    $rv = Genome::Sys->shellcmd(
        cmd => $count_cmd,
        input_files => [
            @deduped_reads, $list_files{'deduped_reads'},
            @reference_fastas, $list_files{'reference_fastas'}],
        output_files => [@counted_reads]
    );
    unless($rv) { die $self->error_message("Methylation mapping failed."); }

    ##for testing
    # system("cp $scratch_directory/* /gscmnt/sata921/info/medseq/cmiller/methylSeq/tmp/scratch2/");
    # system("cp $list_file /gscmnt/sata921/info/medseq/cmiller/methylSeq/tmp/scratch2/");
    # system("cp $list2_file /gscmnt/sata921/info/medseq/cmiller/methylSeq/tmp/scratch2/");
    # system("cp $refs_file /gscmnt/sata921/info/medseq/cmiller/methylSeq/tmp/scratch2/");




    ###################################################
    # clean up
    ###################################################
    # move the methMap output files to the staging dir
    # this is redundant? just create them in the staging directory...
    #move("$scratch_directory/map_forw.txt", $staging_directory) or die $self->error_message(
        #"Failed to move forward methylation map ($scratch_directory/map_forw.txt) to staging directory ($staging_directory).");
    #move("$scratch_directory/map_rev.txt", $staging_directory) or die $self->error_message(
        #"Failed to move reverse methylation map ($scratch_directory/map_rev.txt) to staging directory ($staging_directory).");

    # confirm that at the end we have a nonzero sam file, this is what'll get turned into a bam and copied out.
    unless (-s $sam_file) { die $self->error_message("The sam output file $sam_file is zero length; something went wrong."); }

    # TODO:
    # If you have any log files from the aligner you're wrapping that you'd like to keep,
    # copy them out into the staging directory here.

    # TODO:
    # Do any last minute checks on the staged data and die if they fail.

    # If we got to here, everything must be A-OK.  AlignmentResult will take over from here
    # to convert the sam file to a BAM and copy everything out.
    return 1;
}

# TODO: This should be the command line used to run your aligner, not just the params.
# sorry for the mis-named method name, it'll get fixed soon.
#
# This will end up in our re-composed sam/bam header.
sub aligner_params_for_sam_header {
    my $self = shift;

    my %aligner_params = $self->decomposed_aligner_params;
    
    return sprintf("trim %s ; brat-large %s ; acgt-count %s",
        $aligner_params{'trim_options'},
        $aligner_params{'align_options'},
        $aligner_params{'count_options'}
    );
}

sub decomposed_aligner_params {
    my $self = shift;
    
    my $full_params;

    if (ref($self)) { # if this is an instance of AlignmentResult
        $full_params = $self->aligner_params;
    } else {
        $full_params = shift;
    }

    # split a colon-delimited list of arguments
    my @params = split(":", $full_params || "::");

    my @defaults = ("-q 20 -m 2", "-m 10 -bs -S", "-B");
    # trim_options: default to -q 20 and -m 2
    # align_options: default to -m 10 (number of mismatches) -bs (bisulfite option) -S (faster, at the expense of more mem)
    # count_options: default to -B (get a map of methylation events, not a count of every base)
    
    # create our params hash, using default arguments if none were supplied
    my %aligner_params = (
        'trim_options' => $params[0] || $defaults[0],
        'align_options' => $params[1] || $defaults[1],
        'count_options' => $params[2] || $defaults[2]
    );

    # attemp to compact and sort command-line arguments for consistency
    for my $step (keys %aligner_params) {
        # compacts strings of whitespace down to a single character; strips all white space from beginning and end of string
        $aligner_params{$step} =~ s/(^)?(?(1)\s+|\s+(?=\s|$))//g;
        # split by each argument, sort, rejoin
        $aligner_params{$step} = join(" ",sort(split(/\s(?=-)/, $aligner_params{$step})));
    }
    
    return %aligner_params;
}

sub _create_temporary_list_file {
    my $self = shift;
    my @items = shift;

    my ($temp_fh, $temp_file) = Genome::Sys->create_temp_file();
    $temp_fh->print(join("\n",@items)."\n");
    $temp_fh->close;

    return $temp_file;
}

sub _split_reference_fasta_by_contig {
    my $class = shift;
    my $reference_fasta_path = shift; # fasta file to read from
    my $staging_directory = shift; # destination directory for split fastas

    my $fasta_fh = IO::File->new("< $reference_fasta_path"); # open all_sequences.fa

    my $line;
    my $total_count = 0;
    my $file_count = 0;
    my $current_fh;
    my @output_fastas;

    while ($line = $fasta_fh->getline()) {
        $total_count++;
        if (substr($line, 0, 1) eq ">") { # starting new contig
            if ($line =~ /^>([1-2]?[0-9]|[XYxy]|MT|NT_\d+)\s.+/) { # contig regex
                if (defined $current_fh) { # if we were processing something before
                    # reset file counter
                    print "\tProcessed $file_count lines.\n";
                    $file_count=0;
                    # close fh
                    $current_fh->close();
                    undef $current_fh;
                }
                # begin a new file
                print "[$total_count] $line";
                print "\tGrabbed '$1'\n";
                my $new_filename = "$staging_directory/$1.fa";
                push @output_fastas, $new_filename;
                $current_fh = IO::File->new("> $new_filename") or die $!;
            } else {
                die $class->error_message("\tCouldn't interpret contig name on line $total_count: $line".
                    "If this happens, review and modify the contig regex in _split_reference_fasta_by_contig in Brat.pm\n");
            }
        }
        $current_fh->print($line);
        $file_count++;
    }

    if (defined $current_fh) { # cleanup
        # print number of lines printed in last file
        print "\tProcessed $file_count lines.\n";
        # close fh
        $current_fh->close();
        undef $current_fh;
    }
    
    $fasta_fh->close();
    undef $fasta_fh;

    return @output_fastas;
}

sub prepare_reference_sequence_index {
    my $class = shift;
    my $reference_index = shift;

    $class->status_message("Creating reference index.");    

    # get refseq info and fasta files
    my $reference_build = $reference_index->reference_build;
    my $reference_fasta_path = $reference_build->full_consensus_path('fa');

    # this is the directory where the index files will be created
    my $staging_directory = $reference_index->temp_staging_directory;

    # decompose aligner params for each stage of alignment
    my %aligner_params = $class->decomposed_aligner_params($reference_index->aligner_params);

    # get the command path
    my $brat_cmd_path = dirname(Genome::Model::Tools::Brat->path_for_brat_version($reference_index->aligner_version)) . "/";

    $DB::single = 1;

    print "Reference fasta path: $reference_fasta_path.\n";
    print "Staging directory: $staging_directory.\n";

    # create reference fastas split by contig
    my @reference_fastas = $class->_split_reference_fasta_by_contig($reference_fasta_path, $staging_directory);

    # create a file that lists all these reference fastas; this is for convenience and so we only have one regex determing contigs used
    my $reference_fasta_list_fh = IO::File->new("> $staging_directory/reference_fasta_list.txt");
    $reference_fasta_list_fh->print(join("\n",map(basename, @reference_fastas))."\n");
    $reference_fasta_list_fh->close();

    print Data::Dumper::Dumper([@reference_fastas]);




    # the following should no longer be necessary because we get the list back from _split_reference_fasta_by_contig
    #opendir(DIR, $reference_directory) or die $!;
    #opendir(DIR, $staging_directory) or die $!; # we now split up all_sequences.fa by contig into .fa in our staging directory
    #while (my $filename = readdir(DIR)) {
    #    # should match 1.fa - 22.fa, along with X.fa, x.fa, Y.fa, y.fa and contigs MT.fa or NT_######.fa
    #    # XXX will fail on other formats (chr22.fa)
    #    if ($filename =~ /^([1-2]?[0-9]|[XYxy]|MT|NT_\d+)\.(fa|fasta)$/) {
    #        push @reference_fastas, "$staging_directory/$filename";
    #    }
    #}
    #closedir(DIR) or die $!;
    
    ## We use the -P option with a pre-built index for alignment
    ## Index creation requires a file that lists reference fastas.

    # the only aligner parameters that brat-large-build needs to know about are -S and -bs; this filters all the others out
    my $filtered_params = join(" ", grep(/^-(?:S|bs)/, split(/\s(?=-)/, $aligner_params{'align_options'})));
    
    my $reference_fastas_list_file = _create_temporary_list_file(@reference_fastas);

    my $index_cmd = sprintf("%s -r %s -P %s %s",
        $brat_cmd_path . "brat-large-build",
        $reference_fastas_list_file,
        $staging_directory,
        $filtered_params # index creation needs to know about certain params passed to the aligner (see above)
    );

    # index filenames are based off of the fasta filenames:
    # for every .fa file in $reference_directory, add a .bg, .hs, and .ht file in $staging_directory to our array. also, tack INFO.txt on to the end.
    my @index_files = map{
            basename($_) =~ /^([1-2]?[0-9]|[XYxy]|MT|NT_\d+)(?=\.fa|\.fasta)/;
            my $filename = $1;
            map{ sprintf("%s/%s.%s",$staging_directory,$filename,$_) } qw(bg hs ht);
        } @reference_fastas;
    my $index_info_file = $staging_directory . "/INFO.txt";

    print Data::Dumper::Dumper([@index_files, $index_info_file]);
    
    $DB::single=1;

    my $rv = Genome::Sys->shellcmd(
        cmd => $index_cmd,
        input_files => [@reference_fastas, $reference_fastas_list_file],
        output_files => [@index_files, $index_info_file]
    );
    
    $DB::single=1;

    unless($rv) { die $class->error_message("Index creation failed."); }

    return 1;
}

sub fillmd_for_sam {
    return 0;
}

sub requires_read_group_addition {
    return 1;
}

sub accepts_bam_input {
    return 0;
}

# TODO investigate this further:
sub supports_streaming_to_bam {
    return 0;
}

sub _convert_mapped_reads_to_sam {
    my ($self, $paired_end, $brat_input_file, $sam_output_file, $trimmed_prefix) = @_;
    ###################################################
    # subroutine for converting to sam format
    # this is harder than it should be because we have to convert
    # the mapped reads, then go back to the fastqs to retrieve
    # the unmapped reads.
    ###################################################

    ###################################################
    # first do the aligned reads
    ###################################################
    $self->status_message("Adding mapped reads to SAM.");

    my $prevNum = -1;
    my %missing = ();

    my $inFh = IO::File->new($brat_input_file) || die "Can't open '$brat_input_file' for sam conversion input.\n";
    my $outFh = open (my $samfile, ">$sam_output_file") || die "Can't open '$sam_output_file' for sam conversion output.\n";

    while( my $line = $inFh->getline ) {
        chomp($line);
        my @fields = split("\t" ,$line);
        my @samline = ();

        if ($paired_end) { #---Paired End---------------------------
            #name = id
            push(@samline,$fields[0] . "/1");

            #strand info goes in flag
            if ($fields[4] eq "+") {
                push(@samline,"99");
            } else {
                push(@samline,"83");
            }

            # "chr" gets added
            # $fields[3] = "chr" . $fields[3] unless ($fields[3] =~ /chr/);
            push(@samline,$fields[3]);

            #pos
            push(@samline,$fields[5]);
            #mapq
            push(@samline,255);

            #cigar - includes length
            push(@samline,length($fields[1]) . "M");

            #other end of pair
            push(@samline,$fields[3]);
            push(@samline,$fields[6]);

            #default vals for the rest
            push(@samline,"0");
            push(@samline,"*");
            push(@samline,"*");

            print $samfile join("\t",@samline) . "\n";

            #now second read - flip positions, etc
            $samline[0] = $fields[0] . "/2";
            if ($fields[4] eq "+") {
                $samline[1] = "147";
            } else {
                $samline[1] = "163";
            }
            $samline[3] = $fields[6];
            $samline[5] = length($fields[2]) . "M"; #cigar
            $samline[7] = $fields[5];
            print $samfile join("\t",@samline) . "\n";
        } else { #---Single End---------------------------
            #name = id
            push(@samline,$fields[0]);

            #strand info goes in flag
            if ($fields[3] eq "+") {
                push(@samline,"0");
            } else {
                push(@samline,"16");
            }

            #"chr" gets added
            #$fields[2] = "chr" . $fields[2] unless ($fields[2] =~ /chr/);
            push(@samline,$fields[2]);

            push(@samline,$fields[4]); #pos
            push(@samline,255);        #mapq
            push(@samline,length($fields[1]) . "M"); #cigar
            #other end of pair
            push(@samline,$fields[3]);
            push(@samline,$fields[5]);
            push(@samline,"0");
            push(@samline,"*");
            push(@samline,"*");

            print $samfile join("\t",@samline) . "\n";
        }

        #also keep track of which sequences didn't get mapped
        $prevNum++;
        while($prevNum < $fields[0]) {
            # $self->status_message("missing $prevNum");
            $missing{$prevNum} = 0;
            $prevNum++;
        }

        $prevNum = $fields[0];
    }
    $inFh->close;

    ###################################################
    # now, add reads that weren't mapped back to sam file. this is a little ugly, 
    # but necessary for the standard pipeline
    ###################################################
    $self->status_message("Adding unmapped reads to SAM.");    

    if ($paired_end) { #---Paired End---------------------------
        #from first trimmed fastq - unmapped reads
        my $count = 0;
        my $fastqF = IO::File->new( $trimmed_prefix."_reads1.txt" ) || die "can't open ".$trimmed_prefix."_reads1.txt\n";

        while( my $line = $fastqF->getline ) {   
            #and if this is one of the sequences that's missing
            if (exists $missing{$count}) {
                chomp($line);
                my @splitline = split("\t",$line);		    
                printUnmappedReadToSam($splitline[0], ("n_" . $count . "/1"), $samfile);
                # also have to handle lines at the end of the fastq that are missing
                # with ids > the highest one output above
                #prevNum will still be equal to the last read output above
            } elsif ($count > $prevNum) {
                chomp($line);
                my @splitline = split("\t",$line);
                printUnmappedReadToSam($line, ("n_" . $count . "/1"), $samfile); # TODO $line looks dubious
            }
            $count++;
        }
        $fastqF->close;

        #now from second trimmed fastq - unmapped reads
        $count = 0;
        $fastqF = IO::File->new( $trimmed_prefix."_reads2.txt" ) || die "can't open ".$trimmed_prefix."_reads2.txt\n";
        while( my $line = $fastqF->getline ) {
            #if we're on a sequence line
#	    if ($count % 4 == 2)
#	    {
            #and if this is one of the sequences that's missing
            if (exists $missing{$count}) {
                chomp($line);
                my @splitline = split("\t",$line);		    
                printUnmappedReadToSam($splitline[0], ("n_" .  $count . "/2"), $samfile);

            # also have to handle lines at the end of the fastq that are missing
            # with ids > the highest one output above
            #prevNum will still be equal to the last read output above
            } elsif ($count > $prevNum) {
                chomp($line);
                my @splitline = split("\t",$line);		    
                printUnmappedReadToSam($splitline[0], ("n_" .  $count . "/2"), $samfile); # TODO this line also looks dubious
            }	    
#	    }
            $count++;
        }
        $fastqF->close;
        
        
        #finally, add the reads where one or more ends was trimmed and set quality scores to 0
        my @files = ($trimmed_prefix."_mates1.seq", $trimmed_prefix."_badMate1.seq",
                 $trimmed_prefix."_mates2.seq", $trimmed_prefix."_badMate2.seq",
                 $trimmed_prefix."_err1.seq", $trimmed_prefix."_err2.seq");
        
        $count = 0;
        foreach my $file (@files) {
            if ( -e $file ){
                $fastqF = IO::File->new( $file ) || die "can't open fastq - $file\n";
                while( my $line = $fastqF->getline ) {
                    printUnmappedReadToSam($line, ("n_" . $count . "/1"), $samfile);	    
                    $count++;
                }
                $fastqF->close;
            } else {
                $self->status_message("couldn't open $file - skipped\n");
            }
        }
    } else { #---Single End---------------------------
        my $count = 0;

        my $fastqF = IO::File->new( $trimmed_prefix."_reads1.txt" ) || die "can't open file: ".$trimmed_prefix."_pair1.fastq\n";
        while( my $line = $fastqF->getline ) {
            #if we're on a sequence line
#	    if ($count % 4 == 2)
#	    {
            #and if this is one of the sequences that's missing
            if (exists $missing{$count}) {
                chomp($line);
                my @splitline = split("\t",$line);		    	
                printUnmappedReadToSam($line, "n_" . $count, $samfile);
                
            # also have to handle lines at the end of the fastq that are missing
                    # with ids > the highest one output above
                #prevNum will still be equal to the last read output above
            } elsif ($count > $prevNum) {
                chomp($line);
                my @splitline = split("\t",$line);		    
                printUnmappedReadToSam($line, "pn_" . $count, $samfile);
            }
     #	    }

            $count++;
        }
        $fastqF->close;

        #next,add the reads where one or more ends couldn't be mapped and set quality scores to 0
        my @files = ($trimmed_prefix."_mates1.seq", $trimmed_prefix."_err1.seq");

        foreach my $file (@files) {
            if ( -e $file ){
                $fastqF = IO::File->new( $file ) || die "can't open fastq $file\n";
                while( my $line = $fastqF->getline ) {
                    printUnmappedReadToSam($line, ("n_" . $count), $samfile);		    
                    $count++;
                }
                $fastqF->close;
            } else {
                $self->status_message("couldn't open $file - skipped\n");
            }
        }
    } ##end if paired_end

    $samfile->close;
}

sub printUnmappedReadToSam {
    my ($line, $name, $samfile) = @_;
    my @samline = ();
    #name = id
    push(@samline,$name);

    #strand info goes in flag
    push(@samline,"4");

    push(@samline,"*");
    push(@samline,0); #pos
    push(@samline,0);        #mapq
    push(@samline,length($line) . "X"); #cigar
    push(@samline,"*");
    push(@samline,"0");
    push(@samline,"0");
    push(@samline,"*");
    push(@samline,"*");

    print $samfile join("\t",@samline) . "\n";
}

    ### XXX TODO
    #    step into the convert reads subroutine and continue to clean it up; it looks like there might be bug (see dubious comment)
    #    other things we need to do:
    # x    correctly grab commands instead of using hard coded paths
    # x    correctly handle parameters instead of using hard coded ones
    #          make sure that parameters that could affect output/refs/indices are processed this way
    #          and ones that DO NOT affect output/refs/indices are NOT included in the _decompose thing
    # x    correctly generate reference indices
    # x        also see prepare_reference_sequence_index
    # y            this doesn't need to be explicitly called, amirite?
    #      it also looks like there are many additional output files, specifically:
    #          my @files = ("$scratch_directory/trimmed_mates1.seq", "$scratch_directory/trimmed_badMate1.seq",
    #              "$scratch_directory/trimmed_mates2.seq", "$scratch_directory/trimmed_badMate2.seq",
    #              "$scratch_directory/trimmed_err1.seq", "$scratch_directory/trimmed_err2.seq");
    # paired end read thing
    # clean up conver_mapped_reads_to_sam
    ### LATER: 
    # streaming to bam
    # check gmt: install package and review other todo

