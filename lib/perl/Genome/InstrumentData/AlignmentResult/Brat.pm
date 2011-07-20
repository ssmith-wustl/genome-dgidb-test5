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
    my $reference_index_directory = dirname($reference_index->full_consensus_path());
    #my $reference_index_directory = $reference_index->data_directory(); # better way to do this?
    print "Ref index dir: $reference_index_directory\n";
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
    #my $import_format = $self->instrument_data->import_format; # TODO what is this supposed to be?

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
        my $instrument_data = $self->instrument_data();
        my $median_insert_size = $instrument_data->median_insert_size();
        my $sd_above_insert_size = $instrument_data->sd_above_insert_size();
        my $sd_below_insert_size = $instrument_data->sd_below_insert_size();

        # TODO this may be an area for improvement
        $min_insert_size = $median_insert_size - (3*$sd_below_insert_size);
        $max_insert_size = $median_insert_size + (3*$sd_above_insert_size);

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

    # Brat uses the concept of "list" files. List files are plain text files that contain a list of required input files.
    # For instance, brat's remove-dupl command requests a single plain-text file that lists all files of aligned reads to dedup.
    # If the output of our alignment step is bratout.dat, then the corresponding list file would contain a single line that has
    # the full path to bratout.dat. Yes, this is really redundant, especially when we only have a single output file.
    my %list_files;
    
    # When creating reference fastas split by contig, we also created a file listing each fasta file.
    # We load this file, get out the filenames, and prefix the correct directory.
    my $reference_fasta_list_fh = IO::File->new("< $reference_index_directory/reference_fasta_list.txt");
    my @reference_fastas = map{$_ =~ /(.+)\n$/; sprintf("%s/%s",$reference_index_directory,$1)} grep(!/^$/, <$reference_fasta_list_fh>);
    $reference_fasta_list_fh->close();

    ## Note that we use the -P option with a pre-built index for alignment, but we still
    ## need the fastas for the acgt count step.
    $list_files{'reference_fastas'} = _create_temporary_list_file(\@reference_fastas);

    # Create the list of expected index files, too.
    my @index_files = map{
            basename($_) =~ /^(.+)(?=\.fa|\.fasta)/;
            my $reference_name = $1;
            map{ sprintf("%s/%s.%s",$reference_index_directory,$reference_name,$_) } qw(bg hs ht);
        } @reference_fastas;
    push @index_files, "$reference_index_directory/INFO.txt";

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
        qw(reads1.txt reads2.txt mates1.txt mates2.txt reads1.fastq reads2.fastq mates1.fastq mates2.fastq badMate1.fastq badMate2.fastq err1.fastq err2.fastq) :
        qw(reads1.txt reads1.fastq err1.fastq);
    
    # we need list files of mates for remove-dupl
    if ($paired_end) { # TODO should something happen when not running in paired end mode? look at documentation for remove-dupl i think...
        $list_files{'mates1'} = _create_temporary_list_file([grep(/.+mates1\.txt$/, @trimmed_files)]);
        $list_files{'mates2'} = _create_temporary_list_file([grep(/.+mates2\.txt$/, @trimmed_files)]);
    }

$DB::single=1;

    # define the trim command and run it
    my $trim_cmd = sprintf("%s %s -P %s %s",
        $brat_cmd_path . "trim",
        $aligner_params{'trim_options'}, # -q 20 and -m 2
        $trim_prefix,
        $paired_end ?
            "-1 $input_pathnames[0] -2 $input_pathnames[1]" : 
            "-s $input_pathnames[0]"
    );
    
    my $rv = $self->_shell_cmd_wrapper(
        cmd => $trim_cmd,
        input_files => [@input_pathnames],
        output_files => [@trimmed_files],
        files_that_may_be_empty => [@trimmed_files]
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
    $list_files{'aligned_reads'} = _create_temporary_list_file(\@aligned_reads);

    # uses precomputed index; alternatively you could do something like -r $list_files{'reference_fastas'} instead of -P $reference_index_dir
    my $align_cmd = sprintf("%s -P %s %s -o %s %s",
        $brat_cmd_path . "brat-large",
        $reference_index_directory,
        $paired_end ?
            "-1 $trimmed_files[0] -2 $trimmed_files[1] -pe -i $min_insert_size -a $max_insert_size" : # TODO bad way to access @trimmed_files
            "-s $trimmed_files[0]",
        $aligned_reads[0],
        $aligner_params{'align_options'} # -m 10 (number of mismatches) -bs (bisulfite option) -S (faster, at the expense of more mem)
    );

    $rv = $self->_shell_cmd_wrapper(
        cmd => $align_cmd,
        input_files => [@trimmed_files, @index_files],
        output_files => [@aligned_reads],
        files_that_may_be_empty => [@trimmed_files, @aligned_reads]
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
    $list_files{'deduped_reads'} = _create_temporary_list_file(\@deduped_reads);

    my $dedup_cmd = sprintf("%s -r %s %s",
        $brat_cmd_path . "remove-dupl",
        $list_files{'reference_fastas'}, # reference fastas.
        $paired_end ?
            # we specify -1 and -2 with files from trim; this is brat's way of dealing with "overlapping mates"
            #"-p $list_files{'aligned_reads'} -1 $list_files{'mates1'} -2 $list_files{'mates2'}" :
            "-p $list_files{'aligned_reads'}" :
            "-s $list_files{'aligned_reads'}"
    );

    $rv = $self->_shell_cmd_wrapper(
        cmd => $dedup_cmd,
        input_files =>
            $paired_end ? [
                @reference_fastas, $list_files{'reference_fastas'},
                @aligned_reads, $list_files{'aligned_reads'},
                #$trimmed_files[2], $list_files{'mates1'},
                #$trimmed_files[3], $list_files{'mates2'}
            ] : [
                @reference_fastas, $list_files{'reference_fastas'},
                @aligned_reads, $list_files{'aligned_reads'}
            ],
        output_files => [@deduped_reads],
        files_that_may_be_empty => [@aligned_reads, @deduped_reads]
    );
    unless($rv) { die $self->error_message("Deduping failed."); }




    ###################################################
    # sort reads
    ###################################################
    $self->status_message("Sorting reads.");

    my @sorted_deduped_reads = map{$_ . ".sorted"} @deduped_reads;

    my $sort_cmd = "sort -nk1 $deduped_reads[0] >$sorted_deduped_reads[0]";

    $rv = $self->_shell_cmd_wrapper(
        cmd => $sort_cmd,
        input_files => [@deduped_reads],
        output_files => [@sorted_deduped_reads],
        files_that_may_be_empty => [@deduped_reads, @sorted_deduped_reads]
    );
    unless($rv) { die $self->error_message("Sorting deduped files failed."); }




    ###################################################
    # convert to sam format
    ###################################################
    $self->status_message("Converting output to SAM format.");

    my $temp_sam_output = "$scratch_directory/mapped_reads.sam";
    $self->_convert_reads_to_sam($paired_end, $sorted_deduped_reads[0], $temp_sam_output, $trim_prefix);




    ###################################################
    # sort sam file and append to all_sequences.sam
    ###################################################
    $self->status_message("Sorting SAM file and appending to all_sequences.sam.");
    $DB::single = 1;

    my $append_cmd = "sort -nk 1 $temp_sam_output >> $sam_file";

    $rv = $self->_shell_cmd_wrapper(
        cmd => $append_cmd,
        input_files => [$temp_sam_output],
        output_files => [$sam_file],
        skip_if_output_is_present => 0 # because there will already be an all_sequences.sam we're appending to
    );
    unless($rv) { die $self->error_message("Sorting temporary sam file and appending to all_sequences.sam failed."); }




    ###################################################
    # create the methylation map
    ###################################################
    $self->status_message("Creating methylation map.");

    my $count_prefix = $staging_directory . "/map";
    
    my @counted_reads = ();

    if ($aligner_params{'count_options'} =~ /-B/) {
        #@counted_reads = map{sprintf("%s_%s.txt",$count_prefix,$_)} qw(forw rev);
        @counted_reads = map{
                basename($_) =~ /^(.+)(?=\.fa|\.fasta)/;
                my $reference_name = $1;
                map{ sprintf("%s_%s_%s.txt",$count_prefix,$_,$reference_name) } qw(forw rev);
            } @reference_fastas;
    } else {
        die $self->error_message("Unimplemented: acgt-count should be run with the -B option.");
        # possible TODO
        # if the user doesn't use the -B switch, acgt-count creates a count of every base instead of a methylation map
        # in this case, acgt-count outputs $prefix_forw_refname and $prefix_rev_refname for every reference file
        # the following code creates this list of output files:
        #@counted_reads = map{
        #        my $filename = basename($_);
        #        # confirm that the following is the actual output filename format; move code below suggests otherwise
        #        map{ sprintf("%s_%s_%s",$count_prefix,$_,$filename) } qw(forw rev);
        #    } @reference_fastas;
    }

    my $count_cmd = sprintf("%s -r %s -P %s %s",
        $brat_cmd_path . "acgt-count",
        $list_files{'reference_fastas'},
        $count_prefix,
        $paired_end ?
            # From BRAT manual:
            # Please note that if a user has paired-end reads (files with mates 1 and mates 2)
            # and wishes to map the mates as single-end reads, then the user must provide names
            # of the files with results for mates 1 and mates 2 separately using options -1 and
            # -2. This will ensure unbiased ACGT-counting when reads are sequenced from two
            # original genomic strands.
            #"-p $list_files{'deduped_reads'} -1 $list_files{'mates1'} -2 $list_files{'mates2'}" : # TODO might be very wrong; manual says we might need to use -1 -2 instead of -p
            "-p $list_files{'deduped_reads'}" :
            "-s $list_files{'deduped_reads'}",
        $aligner_params{'count_options'} # -B (get a map of methylation events, not a count of every base)
    );

print "\n\nDEBUG INFO\n\n\n";
print Data::Dumper::Dumper(\%list_files) . "\n";
print Data::Dumper::Dumper(\@deduped_reads) . "\n";
print Data::Dumper::Dumper(\@reference_fastas) . "\n";
print Data::Dumper::Dumper(\@counted_reads) . "\n";
print Data::Dumper::Dumper(\@index_files) . "\n";
print $count_cmd . "\n";
print `ls -lR $scratch_directory`."\n";
print `ls -lR $staging_directory`."\n";
for my $lf (keys %list_files) {
    print "$lf: $list_files{$lf}\n";
    print `cat $list_files{$lf}`."\n";
}
print `ls -lR $staging_directory`."\n";
system("touch /gscuser/iferguso/brat_lock");
print "\n\nEND DEBUG INFO\n\n\n";

    $rv = $self->_shell_cmd_wrapper(
        cmd => $count_cmd,
        input_files => [
            @deduped_reads, $list_files{'deduped_reads'},
            @reference_fastas, $list_files{'reference_fastas'}],
            #$trimmed_files[2], $list_files{'mates1'},
            #$trimmed_files[3], $list_files{'mates2'}
        output_files => [@counted_reads],
        files_that_may_be_empty => [@deduped_reads]
    );

    unless($rv) { die $self->error_message("Methylation mapping failed."); }


    $DB::single = 1;

    ###################################################
    # clean up
    ###################################################
    
    #$self->status_message("Copying '$sam_file' to '/gscuser/iferguso/brat_all_sequences.sam'.");
    #copy($sam_file, "/gscuser/iferguso/brat_all_sequences.sam") or die $self->error_message("Debug copy of all_sequences.sam failed");

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
    my @items = @{(shift)};

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
    
    
    #my $limiter = 1; # debugging purposes only

    while (($line = $fasta_fh->getline())) {
        $total_count++;
        if (substr($line, 0, 1) eq ">") { # starting new contig
            if ($line =~ /^>([1-2]?[0-9]|[XYxy]|MT|NT_\d+)\s.+/) { # contig regex
                if (defined $current_fh) { # if we were processing something before
                    #if ($limiter-- == 0) { last; } # debugging purposes only
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

    print "Reference fasta path: $reference_fasta_path.\n";
    print "Staging directory: $staging_directory.\n";

    # create reference fastas split by contig
    my @reference_fastas = $class->_split_reference_fasta_by_contig($reference_fasta_path, $staging_directory);

    # create a file that lists all these reference fastas; this is for convenience and so we only have one regex determing contigs used
    my $reference_fasta_list_fh = IO::File->new("> $staging_directory/reference_fasta_list.txt");
    $reference_fasta_list_fh->print(join("\n",map({basename($_)} @reference_fastas))."\n");
    $reference_fasta_list_fh->close();


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
    
    my $reference_fastas_list_file = _create_temporary_list_file(\@reference_fastas);

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

    my $rv = Genome::Sys->shellcmd(
        cmd => $index_cmd,
        input_files => [@reference_fastas, $reference_fastas_list_file],
        output_files => [@index_files, $index_info_file]
    );
    
    unless($rv) { die $class->error_message("Index creation failed."); }

    return 1;
}

sub fillmd_for_sam {
    return 1;
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

#############################
# everything that follows is for converting brats output into sam
#############################

sub _convert_reads_to_sam {
    my ($self, $paired_end, $brat_input_file, $sam_output_file, $trimmed_prefix) = @_;
    
    if (!$paired_end) {$DB::single = 1;}
    # TODO if read is unmapped, include softclip in cigar string anyways? (currently not)
    # TODO need some way to warn if we're not parsing files from an unmodified version of brat

    #my $paired_end = 1;
    #my $brat_input_file = "bratout.dat.nodupl.sorted";
    #my $sam_output_file = "all_reads.sam";
    #my $trimmed_prefix = "trimmed";

    my $outFh = IO::File->new(">$sam_output_file") || die $self->error_message("Can't open '$sam_output_file' for sam conversion output.\n");
    my $bratoutFh = IO::File->new($brat_input_file) || die $self->error_message("Can't open '$brat_input_file' for sam conversion input.\n");

    my @sam_keys = qw(qname flag rname pos mapq cigar rnext pnext tlen seq qual);

    my @aligned_file_pairs;
    my @unaligned_file_pairs;

    if ($paired_end) {
        @aligned_file_pairs = (
            {fastq => 'reads1.fastq', txt => 'reads1.txt'},
            {fastq => 'reads2.fastq', txt => 'reads2.txt'}
        );
        @unaligned_file_pairs = (
            {fastq => 'err1.fastq', txt => undef},
            {fastq => 'err2.fastq', txt => undef},
            {fastq => 'badMate1.fastq', txt => undef},
            {fastq => 'badMate2.fastq', txt => undef},
            {fastq => 'mates1.fastq', txt => 'mates1.txt'},
            {fastq => 'mates2.fastq', txt => 'mates2.txt'}
        );
    } else {
        @aligned_file_pairs = (
            {fastq => 'reads1.fastq', txt => 'reads1.txt'}
        );
        @unaligned_file_pairs = (
            {fastq => 'err1.fastq', txt => undef},
        );
    }

    for my $pair (@aligned_file_pairs, @unaligned_file_pairs) {
        for (keys %{$pair}) {
            $pair->{$_} = sprintf("%s_%s", $trimmed_prefix, $pair->{$_}) if defined($pair->{$_});
        }
    }

    # First, process reads that were handed to the aligner, handling both mapped and unmapped reads.
    # This is a bit complicated: in the case of paired-end reads, we have to read both pairs at once
    # from both the .fastq and .txt file, in addition to keeping track of the next aligned read from
    # bratout.dat
    my @fastq_fhs;
    my @txt_fhs;

    while (my $pair = shift @aligned_file_pairs) {
        push @fastq_fhs, IO::File->new($pair->{'fastq'}) || die $self->error_message("Can't open '$pair->{'fastq'}' for sam conversion input.\n");
        push @txt_fhs, IO::File->new($pair->{'txt'}) || die $self->error_message("Can't open '$pair->{'txt'}' for sam conversion input.\n");
    }

    my $record_count = 0;
    my $bratout_record = undef;

    my $count = $paired_end ? 1 : 0;

    while (1) {
        # load a record from each file handle
        my @fastq_records = map $self->_pull_fq_record_from_fh($_), @fastq_fhs;
        my @txt_records = map $self->_pull_trim_record_from_fh($_), @txt_fhs;
        
        # determine if we're at the end or if one file finished prematurely
        # (a pair of files should end at same time since they're the same reads in a different formats)
        my @empty_records = grep {$_ == 0} (@fastq_records, @txt_records);
        if (scalar(@empty_records)) {
            die $self->error_message("The fastq and trim txt files did not end at the same time") unless (
                scalar(@empty_records) == scalar(@fastq_records) + scalar(@txt_records)
            );
            last;
        }

        # if there are still aligned reads left, load one into bratout_record if there isn't one there already
        if (defined($bratoutFh) && !defined($bratout_record)) {
            $bratout_record = $self->_pull_bratout_record_from_fh($bratoutFh);
            if ($bratout_record == 0) {
                $bratoutFh->close();
                $bratoutFh = undef;
                $bratout_record = undef;
            }
        }

        my @reads; 

        # create our read structures
        for (0..$count) {
            # make sure that both the .fastq and .txt are refering to the same read
            die $self->error_message("Trimmed read from .txt was not a substring of the read from .fastq") unless (
                index($fastq_records[$_]->{'sequence'}, $txt_records[$_]->{'clipped_seq'}) != -1
            );
            push @reads, {
                qname => $fastq_records[$_]->{'id'},
                sequence => $fastq_records[$_]->{'sequence'},
                qual => $fastq_records[$_]->{'qual'},
                mapped => 0,
                pair => $fastq_records[$_]->{'pair'},
                clipped_seq => $txt_records[$_]->{'clipped_seq'},
                reads_clipped_from_front => $txt_records[$_]->{'reads_clipped_from_front'},
                reads_clipped_from_end => $txt_records[$_]->{'reads_clipped_from_end'}
            };
        }

        # If this happens to be an aligned read (the indices of the reads match), then load in that data too.
        # Otherwise, the next aligned read must be later in the file, so keep going.
        if (defined($bratout_record) and $record_count == $bratout_record->{'brat_index'}) {
            if ($paired_end) {
                # make sure the reads are the same
                die $self->error_message("Trimmed read from .txt was not the same as aligned read in bratout.dat") unless (
                    $reads[0]->{'clipped_seq'} eq $bratout_record->{'sequence_1'} and
                    $reads[1]->{'clipped_seq'} eq $bratout_record->{'sequence_2'}
                );

                $reads[0]->{'reference_name'} = $bratout_record->{'reference_name'}; # ie, chr
                $reads[0]->{'strand'} = $bratout_record->{'strand'};
                $reads[0]->{'trimmed_pos'} = $bratout_record->{'pos_1'} + 1; # 0-based pos, so we add 1
                $reads[0]->{'orig_pos'} = $bratout_record->{'orig_pos_1'} + 1; # 0-based pos, so we add 1
                $reads[0]->{'mismatches'} = $bratout_record->{'mismatches_1'};
                $reads[0]->{'mapped'} = 1;

                $reads[1]->{'reference_name'} = $bratout_record->{'reference_name'}; # ie, chr
                $reads[1]->{'strand'} = $bratout_record->{'strand'};
                $reads[1]->{'trimmed_pos'} = $bratout_record->{'pos_2'} + 1; # 0-based pos, so we add 1
                $reads[1]->{'orig_pos'} = $bratout_record->{'orig_pos_2'} + 1; # 0-based pos, so we add 1
                $reads[1]->{'mismatches'} = $bratout_record->{'mismatches_2'};
                $reads[1]->{'mapped'} = 1;
            } else {
                # make sure the reads are the same
                die $self->error_message("Trimmed read from .txt was not the same as aligned read in bratout.dat") unless (
                    $reads[0]->{'clipped_seq'} eq $bratout_record->{'sequence'}
                );

                $reads[0]->{'reference_name'} = $bratout_record->{'reference_name'}; # ie, chr
                $reads[0]->{'strand'} = $bratout_record->{'strand'};
                $reads[0]->{'trimmed_pos'} = $bratout_record->{'pos'} + 1; # 0-based pos, so we add 1
                $reads[0]->{'orig_pos'} = $bratout_record->{'orig_pos'} + 1; # 0-based pos, so we add 1
                $reads[0]->{'mismatches'} = $bratout_record->{'mismatches'} + 1;
                $reads[0]->{'mapped'} = 1;
            }

            # reset $bratout_record to undef so we load in a new one during the next loop
            $bratout_record = undef;
        }
        
        my @sam_records;
        if ($paired_end) {
            push @sam_records, $self->_calculate_sam_record($reads[0], $reads[1]);
            push @sam_records, $self->_calculate_sam_record($reads[1], $reads[0]);
        } else {
            push @sam_records, $self->_calculate_sam_record($reads[0]);
        }
        
        for my $sam_record (@sam_records) {
            my @sam_line;
            for (@sam_keys) {
                push @sam_line, $sam_record->{$_};
            }
            print $outFh join("\t", @sam_line) . "\n";
        }

        $record_count++;
    }

    for (@fastq_fhs, @txt_fhs) {
        $_->close();
    }
    # if bratout.dat is still open, make sure there are no reads left in it and close it
    # normally it would be closed before this, unless the very last read in the pair.fastq and read.txt files was ALSO aligned
    if (defined($bratoutFh)) {
        if (defined($bratoutFh->getline())) {
            die $self->error_message("There were still reads in bratout.dat even though we were supposedly finished with it");
        } else {
            $bratoutFh->close();
        }
    }

    # Last, we process pairs of files that were not run through the aligner.
    # Some are trimmed and have both a .fastq and .txt, some were not trimmed and are just a .fastq.
    for my $file_pair (@unaligned_file_pairs) {
        my $fastq_fh = IO::File->new($file_pair->{'fastq'}) || die $self->error_message("Can't open '$file_pair->{'fastq'}' for sam conversion input.\n");
        my $txt_fh = undef;
        if (defined($file_pair->{'txt'})) {
            $txt_fh = IO::File->new($file_pair->{'txt'}) || die $self->error_message("Can't open '$file_pair->{'txt'}' for sam conversion input.\n");
        }
        
        while (1) {
            my $fastq_record = $self->_pull_fq_record_from_fh($fastq_fh);
            my $txt_record = $self->_pull_trim_record_from_fh($txt_fh) if defined($txt_fh);;
            
            # determine if we're at the end or if one file finished prematurely
            # (a pair of files should end at same time since they're the same reads in a different formats)
            if ($fastq_record == 0 || (defined($txt_fh) && $txt_record == 0) ) {
                if ( ($fastq_record == 0) && (!defined($txt_fh) || (defined($txt_fh) && ($txt_record == 0)) ) ) {
                    last;
                } else {
                    die $self->error_message("The fastq and trim txt files did not end at the same time");
                }
            }
            
            # make our read
            my $read = {
                qname => $fastq_record->{'id'},
                sequence => $fastq_record->{'sequence'},
                qual => $fastq_record->{'qual'},
                mapped => 0,
                pair => $fastq_record->{'pair'},
                clipped_seq => defined($txt_record) ? $txt_record->{'clipped_seq'} : $fastq_record->{'sequence'},
                reads_clipped_from_front => defined($txt_record) ? $txt_record->{'reads_clipped_from_front'} : 0,
                reads_clipped_from_end => defined($txt_record) ? $txt_record->{'reads_clipped_from_end'} : 0,
            };

            # make our sam
            my $sam_record = $self->_calculate_sam_record($read);
            
            my @sam_line;
            for (@sam_keys) {
                push @sam_line, $sam_record->{$_};
            }
            
            print $outFh join("\t", @sam_line) . "\n";
        }
        
        $fastq_fh->close();
        $txt_fh->close() if defined($txt_fh);
    }

    $outFh->close();
}

sub _pull_bratout_record_from_fh {
    my $self = shift;
    my $bratout_fh = shift;

    my $line = $bratout_fh->getline();
    
    if (!defined($line)) {
        return 0;
    } else {
        chomp($line);
    }

    my @fields = split("\t", $line);
    
    if (scalar(@fields) == 11) {
        return {
            brat_index => $fields[0],
            sequence_1 => $fields[1],
            sequence_2 => $fields[2],
            reference_name => $fields[3], # ie, chr
            strand => $fields[4],
            pos_1 => $fields[5], # 0-based pos
            pos_2 => $fields[6], # 0-based pos
            mismatches_1 => $fields[7], # unused
            mismatches_2 => $fields[8], # unused
            orig_pos_1 => $fields[9],
            orig_pos_2 => $fields[10]
        };
    } elsif (scalar(@fields) == 7) {
        return {
            brat_index => $fields[0],
            sequence => $fields[1],
            reference_name => $fields[2], # ie, chr
            strand => $fields[3],
            pos => $fields[4], # 0-based pos
            mismatches => $fields[5], # unused
            orig_pos => $fields[6],
        };
    } else {
        die $self->error_message("Error when pulling record from bratout.dat file (appears to be malformed)");
    }
}

sub _pull_fq_record_from_fh {
    my $self = shift;
    my $fq_fh = shift;

    my $fastq_id = $fq_fh->getline();
    my $fastq_sequence = $fq_fh->getline();
    $fq_fh->getline(); # skip the +
    my $fastq_qual = $fq_fh->getline();
    
    if (!defined($fastq_id) || !defined($fastq_sequence) || !defined($fastq_qual)) {
        return 0;
    } else {
        chomp($fastq_id);
        chomp($fastq_sequence);
        chomp($fastq_qual);
    }

    # chop the /1 or /2 from the end of the read id
    $fastq_id =~ /^@(.+?)(?:\/([12]))?$/; # this is probably unnecessary in non pe reads
    $fastq_id = $1;
    my $pair = $2;
    
    return {
        id => $fastq_id,
        sequence => $fastq_sequence,
        qual => $fastq_qual,
        pair => defined($pair) ? $pair : '0'
    };
}

sub _pull_trim_record_from_fh {
    my $self = shift;
    my $txt_fh = shift;

    my $line = $txt_fh->getline();
    
    if (!defined($line)) {
        return 0;
    } else {
        chomp($line);
    }
    
    my @fields = split("\t", $line);

    return {
        clipped_seq => $fields[0],
        reads_clipped_from_front => $fields[1],
        reads_clipped_from_end => $fields[2]
    };
}

sub _calculate_sam_flag {
    my $self = shift;
    my $read = shift;
    
    # about $read->{'strand'}
    # in paired-end context:
    # + if 5' mate is mapped to forw strand and 3' mate is mapped to rev strand
    # - if 3' mate is mapped to forw strand and 5' mate is mapped to rev strand
    # in single-end context:
    # + if read is mapped to forw strand and - if read is mapped to rev strand

    if ($read->{'mapped'}) {
        if ($read->{'pair'} eq "1") {
            if ($read->{'strand'} eq "+") {
                return 99; # 0110 0011 - first frag in paired template, pair is reverse complemented
            } elsif ($read->{'strand'} eq "-") {
                return 83; # 0101 0011 - first frag in paired template, this is reverse complemented
            }
        } elsif ($read->{'pair'} eq "2") {
            if ($read->{'strand'} eq "+") {
                return 147; # 1001 0011 - last frag in paired template, this is reverse complemented
            } elsif ($read->{'strand'} eq "-") {
                return 163; # 1010 0011 - last frag in paired template, pair is reverse complemented
            }
        } elsif ($read->{'pair'} eq "0") {
            if ($read->{'strand'} eq "+") {
                return 0; # 0000 0000 - single frag
            } elsif ($read->{'strand'} eq "-") {
                return 16; # 0001 0000 - single frag, reverse complemented
            }
        }
    } else {
        if ($read->{'pair'} eq "1") {
            return 69; # 0100 0101 - first fragment unmapped
        } elsif ($read->{'pair'} eq "2") {
            return 133; # 1000 0101 - last fragment unmapped
        } elsif ($read->{'pair'} eq "0") {
            return 4; # 0000 0100 - unpaired fragment unmapped
        }
    }
    die $self->error_message("Couldn't calculate sam flag");
}

sub _calculate_cigar_string {
    my $self = shift;
    my $read = shift;
    
    #my $length = length($read->{'sequence'});
    #my $clipped_length = defined($read->{'clipped_seq'}) ? length($read->{'clipped_seq'}) : $length;
    if ($read->{'mapped'}) {
        my $front_clipped = $read->{'reads_clipped_from_front'};
        my $end_clipped = $read->{'reads_clipped_from_end'};
        my $front = $front_clipped > 0 ? $front_clipped . 'S' : '';
        my $end = $end_clipped > 0 ? $end_clipped . 'S' : '';
        return sprintf("%s%s%s%s", $front, length($read->{'clipped_seq'}), 'M', $end);
    } else {
        return sprintf("%s%s", length($read->{'sequence'}), 'X');
    }
}

sub _calculate_sam_record {
    my $self = shift;
    my $read = shift;
    my $paired_read = shift;
    
    my $rnext = "*";
    my $pnext = 0;
    if ($read->{'mapped'}) {
        my @required_keys = qw(qname pair strand reference_name orig_pos clipped_seq reads_clipped_from_front reads_clipped_from_end sequence qual);
        die $self->error_message("Read was missing required key(s) in _calculate_sam_record") if (grep !defined($read->{$_}), @required_keys);
        if (defined($paired_read)) {
            die $self->error_message("Paired read was missing required key(s) in _calculate_sam_record") if (grep !defined($read->{$_}), @required_keys);
            $rnext = ($paired_read->{'reference_name'} eq $read->{'reference_name'}) ?
                "=" : $paired_read->{'reference_name'};
            $pnext = $paired_read->{'orig_pos'};
        }
        return {
            qname => $read->{'qname'},
            flag => $self->_calculate_sam_flag($read),
            rname => $read->{'reference_name'},
            pos => $read->{'orig_pos'}, # 1-based pos is already given
            mapq => 255, # 255 = qual unavailable
            cigar => $self->_calculate_cigar_string($read),
            rnext => $rnext,
            pnext => $pnext,
            tlen => 0,
            seq => $read->{'sequence'},
            qual => $read->{'qual'}
        };
    } else {
        my @required_keys = qw(qname pair clipped_seq reads_clipped_from_front reads_clipped_from_end sequence qual);
        die $self->error_message("Read was missing required key(s) in _calculate_sam_record") if (grep !defined($read->{$_}), @required_keys);
        return {
            qname => $read->{'qname'},
            flag => $self->_calculate_sam_flag($read),
            rname => "*",
            pos => 0,
            mapq => 0, # 255 = qual unavailable
            cigar => $self->_calculate_cigar_string($read),
            rnext => $rnext,
            pnext => $pnext,
            tlen => 0,
            seq => $read->{'sequence'},
            qual => $read->{'qual'}
        };
    }
}

# because Genome::Sys::shellcmd is not doing what I expect it to when checking inputs and outputs
sub _shell_cmd_wrapper {
    my ($self,%params) = @_;
    my $cmd                        = delete $params{cmd};
    my $input_files                = delete $params{input_files};
    my $output_files               = delete $params{output_files} ;
    my $files_that_may_be_empty    = delete $params{files_that_may_be_empty};
    my $skip_if_output_is_present  = delete $params{skip_if_output_is_present};

    $skip_if_output_is_present = 1 if not defined $skip_if_output_is_present;
    
    my @missing_inputs;
    if ($input_files and @$input_files) {
        for my $input_file (@$input_files) { # for all inputs
            if (not -p $input_file) { # add the file to the list if it is not a pipe and either one of the following is true:
                if ($files_that_may_be_empty and @$files_that_may_be_empty and (grep {$_ eq $input_file} @$files_that_may_be_empty) ) {
                    if (not -e $input_file) { # the file is non-existent (but it is allowed to be empty)
                        push @missing_inputs, $input_file;
                        $self->status_message("Allowing zero-sized input $input_file");
                    }
                } else {
                    push @missing_inputs, $input_file unless -s $input_file; # the file is non-existent or empty
                }
            }
        }
    }
    if (scalar(@missing_inputs)) {
        die $self->error_message("Input files were missing when attempting to run $cmd:\n".Data::Dumper::Dumper(\@missing_inputs));
    }
    

    my $rv = Genome::Sys->shellcmd(
        cmd => $cmd,
        skip_if_output_is_present => $skip_if_output_is_present,
        input_files => $input_files,
        output_files => $output_files
    );

    my @missing_outputs;
    if ($output_files and @$output_files) {
        for my $output_file (@$output_files) {
            if (not -p $output_file) { # add the file to the list if it is not a pipe and either one of the following is true:
                if ($files_that_may_be_empty and @$files_that_may_be_empty and (grep {$_ eq $output_file} @$files_that_may_be_empty) ) {
                    if (not -e $output_file) { # the file is non-existent (but it is allowed to be empty)
                        push @missing_outputs, $output_file;
                        $self->status_message("Allowing zero-sized output $output_file");
                    }
                } else {
                    push @missing_outputs, $output_file unless -s $output_file; # the file is non-existent or empty
                }
            }
        }
    }
    if (scalar(@missing_outputs)) {
        die $self->error_message("Output files were missing when attempting to run $cmd:\n".Data::Dumper::Dumper(\@missing_outputs));
    }

    return $rv;
}

    ### TODO
    ### LATER: 
    # check gmt: install package and review other todo

