package Genome::InstrumentData::AlignmentResult::Bsmap;

use strict;
use warnings;
use IO::File;
use File::Basename;
use File::Copy;
use File::Temp;
use Sort::Naturally;
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

class Genome::InstrumentData::AlignmentResult::Bsmap {
    is => 'Genome::InstrumentData::AlignmentResult',
    has_constant => [
        aligner_name => { value => 'bsmap', is_param=>1 }
    ]
};

sub required_arch_os { 'x86_64' }

# LSF resources required to run the alignment.
#"-R 'select[model!=Opteron250 && type==LINUX64 && mem>16000 ** tmp > 150000] span[hosts=1] rusage[tmp=150000, mem=16000]' -M 16000000 -n 1";
sub required_rusage {
    my $self = shift;
    my $cores = 4; # default to 4, although decomposed_aligner_params should always include "-p N" even if the processing-profile does not

    my $params = $self->decomposed_aligner_params();
    if ($params =~ /-p\s+(\d+)/) {
        $cores = $1;
    }

    return "-R 'select[type==LINUX64 && mem>16000 && tmp > 100000] span[hosts=1] rusage[tmp=100000, mem=16000]' -M 16000000 -n $cores";
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

    # get the index directory
    #my $reference_index = $self->get_reference_sequence_index();
    #my $reference_index_directory = dirname($reference_index->full_consensus_path());

    #my $reference_index_directory = $reference_index->data_directory(); # better way to do this?
    #print "Ref index dir: $reference_index_directory\n";
    # example dir /gscmnt/sata921/info/medseq/cmiller/methylSeq/bratIndex

    # This is your scratch directory.  Whatever you put here will be wiped when the alignment
    # job exits.
    my $scratch_directory = $self->temp_scratch_directory;

    # This is (another) temporary directory. The difference between this and the scratch directory is that
    # this is blown away between calls of _run_aligner when running in force_fragment mode, while
    # the scratch directory will stick around.
    my $temporary_directory = File::Temp->tempdir("_run_aligner_XXXXX", DIR => $scratch_directory);
    
    # This is the alignment output directory.  Whatever you put here will be synced up to the
    # final alignment directory that gets a disk allocation.
    my $staging_directory = $self->temp_staging_directory;

    # This is the SAM file you should be appending to.  Dont forget, no headers!
    my $sam_file = $scratch_directory . "/all_sequences.sam";
    # import format
    #my $import_format = $self->instrument_data->import_format; # TODO what is this supposed to be?

    # decompose aligner params for each stage of alignment
    my $aligner_params = $self->decomposed_aligner_params;

    # get the command path
    my $bsmap_cmd_path = Genome::Model::Tools::Bsmap->path_for_bsmap_version($self->aligner_version);

    # Data is single-ended or paired-ended: key off the number of files passed in (1=SE, 2=PE)
    # Under no circumstances should you ever get more than 2 files, if you do then that's bad and
    # you should die.
    my $paired_end = 0;

    my $min_insert_size = -1;
    my $max_insert_size = -1;
    
    $DB::single = 1;
    
    # seems dubious
    for (@input_pathnames) {
        $_ =~ s/^(.+\.(?:bam|sam))(?::[12])?$/$1/g;
    }

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
        
        die $self->error_message("Unable to get insert size info from instrument data")
            unless (defined($median_insert_size) && defined($sd_above_insert_size) && defined($sd_below_insert_size));

        # TODO this may be an area for improvement
        $min_insert_size = $median_insert_size - (3*$sd_below_insert_size);
        $max_insert_size = $median_insert_size + (3*$sd_above_insert_size);
    } else {
        die $self->error_message("_run_aligner called with " . scalar @input_pathnames . " files.  It should only get 1 or 2!");
    }
    
    ###################################################
    # run the bsmap aligner, output into temp sam file
    ###################################################
    $self->status_message("Running bsmap aligner.");
    my $temp_sam_output = $temporary_directory . "/mapped_reads.sam";
    
    my $align_cmd = sprintf("%s %s -d %s %s -o %s",
        $bsmap_cmd_path,
        $paired_end
            ? "-a $input_pathnames[0] -b $input_pathnames[1] -m $min_insert_size -x $max_insert_size"
            : "-a $input_pathnames[0]",
        $reference_fasta_path,
        $aligner_params, # example: -p 4 (4 cores) -z ! (initial qual char) -v 4 (max mismatches) -q 20 (qual trimming)
        $temp_sam_output
    );
    
    my $rv = Genome::Sys->shellcmd(
        cmd => $align_cmd,
        input_files => [@input_pathnames, $reference_fasta_path],
        output_files => [$temp_sam_output]
    );
    unless($rv) { die $self->error_message("Alignment failed."); }

    ###################################################
    # post process the temp sam file:
    ###################################################
    my $fix_clipping_and_run_methratio = 0; # force hard clip fixing and methylation mapping to OFF

    if ($fix_clipping_and_run_methratio) {
        ###################################################
        # fix hard clipped reads and append temp sam file to all_sequences.sam
        ###################################################
        $self->status_message("Adjusting and appending mapped_reads.sam to all_sequences.sam.");
        my $chrFiles = $self->_fix_sam_output($temp_sam_output, $sam_file, @input_pathnames);

        ###################################################
        # run methylation mapping
        ###################################################
        $self->status_message("Running methratio.py.");
        if ($self->decomposed_aligner_params =~ /-R/) {
            # TODO this may have issues in force fragment mode?
            my $methylation_output = $staging_directory . "/output.meth.dat";

            for my $file (@{$chrFiles}) {
                
                my $meth_cmd = sprintf("/usr/bin/python %s/%s %s >> %s",
                    #dirname($bsmap_cmd_path), #TODO fix this
                    dirname("/gscuser/cmiller/usr/src/bsmap-2.1/methratio.py"),
                    "methratio.py",
                    $file,
                    $methylation_output
                );
                
                $rv = Genome::Sys->shellcmd(
                    cmd => $meth_cmd,
                    input_files => [$file],
                    output_files => [$methylation_output],
                    skip_if_output_is_present => 0 # because there will already be an all_sequences.sam we're appending to
                );
                unless($rv) { die $self->error_message("methratio.py failed for file '$file'."); }
            }
        } else {
            $self->status_message("Skipping methratio.py because -R was not specified as an aligner param.");
        }
    } else {
        ###################################################
        # append temp sam file to all_sequences.sam
        ###################################################
        $self->status_message("Appending mapped_reads.sam to all_sequences.sam.");
        
        my $append_cmd = sprintf("cat %s >> %s",
            $temp_sam_output,
            $sam_file
        );

        $rv = Genome::Sys->shellcmd(
            cmd => $append_cmd,
            input_files => [$temp_sam_output],
            output_files => [$sam_file],
            skip_if_output_is_present => 0 # because there will already be an all_sequences.sam we're appending to
        );

        unless($rv) { die $self->error_message("Appending failed."); }
    }
    

    ###################################################
    # clean up
    ###################################################
    
    # confirm that at the end we have a nonzero sam file, this is what'll get turned into a bam and copied out.
    unless (-s $sam_file) { die $self->error_message("The sam output file $sam_file is zero length; something went wrong."); }

    # TODO Any log files for staging directory?
    # TODO Any last minute checks?

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

    my $aligner_params = $self->decomposed_aligner_params();
    
    # the number of processors does not affect the sam file
    $aligner_params =~ s/-p\s+\d+//;

    # recompact white space
    $aligner_params =~ s/(^)?(?(1)\s+|\s+(?=\s|$))//g;    
    
    return "bsmap $aligner_params";
}

sub decomposed_aligner_params {
    # TODO if the user specifies params in the processing profile but neglects to require a necessary param
    #       this will not automatically fill it in
    my $self = shift;
    
    my $full_params;

    if (ref($self)) { # if this is an instance of AlignmentResult
        $full_params = $self->aligner_params();
    } else {
        $full_params = shift;
    }

    # split a colon-delimited list of arguments
    #my @params = split(":", $full_params || "::");

    my $defaults = ("-p 4 -q 20 -v 4 -z ! -R");
    # -p is the number of processors to give it
    # -z ! is required to get the correct quality score output
    # -v is the number of mismatches to allow
    # -q is the minimum quality score used in trimming
    
    
    # create our params hash, using default arguments if none were supplied
    my $aligner_params = $full_params || $defaults;

    # if # of processors is not specified, override it to 4 (bsmap defaults to 1)
    $aligner_params .= " -p 4" unless $aligner_params =~ /-p\s+\d/;

    # attemp to compact and sort command-line arguments for consistency:
    # compacts strings of whitespace down to a single character; strips all white space from beginning and end of string
    $aligner_params =~ s/(^)?(?(1)\s+|\s+(?=\s|$))//g;
    # split by each argument, sort, rejoin
    $aligner_params = join(" ",sort(split(/\s(?=-)/, $aligner_params)));
    
    return $aligner_params;
}

sub prepare_reference_sequence_index {
    my $class = shift;

    $class->status_message("BSMAP doesn't require index preparation, doing nothing.");

    return 0;
}

# TODO assume yes?
sub fillmd_for_sam {
    return 1;
}

# TODO assume yes?
sub requires_read_group_addition {
    return 1;
}

# only accept bam input if we're not running in force fragment mode
sub accepts_bam_input {
    my $self = shift;
    return $self->force_fragment ? 0 : 1;
}

# TODO this might be something to turn on...
sub supports_streaming_to_bam {
    return 0;
}

#####
# The following subroutines are for the disabled soft clip fixing
#####

sub _fix_sam_output {
    my $self = shift;
    my $temp_sam_output = shift;
    my $sam_file = shift;
    my @in_files = @_;
    
    my $reference_build = $self->reference_build;

    my $paired_end = scalar(@in_files) == 2 ? 1 : 0;
    my $is_bam = $self->accepts_bam_input();

    my $alignedFh = IO::File->new("$temp_sam_output") || die $self->error_message("Can't open '$temp_sam_output' for reading.\n");
    my $outFh = IO::File->new(">>$sam_file") || die $self->error_message("Can't open '$sam_file' for appending.\n");

    my $methylation_mapping = $self->decomposed_aligner_params() =~ /-R/ ? 1 : 0;
    my $chrFhs = {
        basename => dirname($temp_sam_output),
        handles => {},
        headers => []
    };
    
    while (my $line = <$alignedFh>) {
        last unless $line =~ /^@.+$/;
        push @{$chrFhs->{headers}}, $line;
    }
    
    seek($alignedFh, 0, 0);
    
    # We build an index against the aligned sam file.
    # For any read we get in the input(s), we can seek to the
    # proper place in the aligned sam file to pull that read.
    # We use the aligned sam because the inputs may not always
    # be sam format and may be piped through samtools.
    my $index = $self->_build_sam_index($temp_sam_output);
    
    # check that our inputs are really bams if we're running with accepts_bam_input
    if ($self->accepts_bam_input) {
        die $self->error_message("Expecting a bam file but that's not what we got")
            unless $in_files[0] =~ /^.+\.bam$/;
        if ($paired_end) {
            die $self->error_message("Expecting the same two bam files, but our paths were different")
                unless $in_files[0] eq $in_files[1];
        }
    }

    if ($paired_end) {
        my @inFhs;
        if ($is_bam) {
            my $fh = IO::File->new("samtools view $in_files[0] | ") || die $self->error_message("Can't pipe 'samtools view $in_files[0] | ' for reading.\n");
            @inFhs = ($fh, $fh); # because both reads are in the same file
        } else {
            @inFhs = map{IO::File->new("$_") || die $self->error_message("Can't open '$_ ' for reading.\n");} @in_files;
        }

        while (1) {
            my @input_records = map{$is_bam ? $self->_pull_sam_record_from_fh_skip_headers($_) : $self->_pull_fq_record_from_fh($_)} @inFhs;


            if (grep{not defined($_)} @input_records) {
                if (scalar(grep{not defined($_)} @input_records) == scalar(@input_records) ) {
                    last;
                } else {
                    die $self->error_message("Input file ended prematurely\n" . Data::Dumper::Dumper([@input_records]));
                }
            }

            # go to the correct position in the aligned sam file
            die $self->error_message("Pulled record pair not sam seq:\n$input_records[0]->{qname}\n$input_records[1]->{qname}")
                unless ($input_records[0]->{qname} eq $input_records[1]->{qname});
            my $seq_to_grab = $input_records[0]->{qname};
            seek($alignedFh, $self->_pull_id_pos_from_index($index, $input_records[0]->{qname}), 0);

            my @aligned_records = map{$self->_pull_sam_record_from_fh_skip_headers($alignedFh)} (1..2);
            
            if (grep{not defined($_)} @aligned_records) {
                die $self->error_message("Unable to pull record(s) from aligned sam file\n" . Data::Dumper::Dumper([@aligned_records]));
            }
            
            my @new_records = (
                $self->_process_record_pair($input_records[0], $aligned_records[0], $reference_build, $methylation_mapping, $chrFhs),
                $self->_process_record_pair($input_records[1], $aligned_records[1], $reference_build, $methylation_mapping, $chrFhs)
            );
            
            # we need to update the positions of the pair
            $new_records[0]->{pnext} = $new_records[1]->{pos};
            $new_records[1]->{pnext} = $new_records[0]->{pos};
            
            # TODO need to fix flags?

            for my $new_record (@new_records) {
                $self->_print_record_to_fh($outFh, $new_record);
            }
        }
        
        map{$_->close()} @inFhs;
        $alignedFh->close();
    } else {
        my $inFh;
        if ($is_bam) {
            # TODO this will fail in force fragment mode, because both records will be present in the one sam file...
            $inFh = IO::File->new("samtools view $in_files[0] | ") || die $self->error_message("Can't pipe 'samtools view $in_files[0] | ' for reading.\n");
        } else {
            $inFh = IO::File->new("$in_files[0]") || die $self->error_message("Can't open '$in_files[0]' for reading.\n");
        }

        while (1) {
            my $input_record = $is_bam ? $self->_pull_sam_record_from_fh_skip_headers($inFh) : $self->_pull_fq_record_from_fh($inFh);

            if (not defined($input_record)) {
                last;
            }
            
            # go to the correct position in the aligned sam file
            my $seq_to_grab = $input_record->{qname};
            seek($alignedFh, $self->_pull_id_pos_from_index($index, $input_record->{qname}), 0);

            my $aligned_record = $self->_pull_sam_record_from_fh_skip_headers($alignedFh);

            if (not defined($aligned_record)) {
                die $self->error_message("Unable to pull record from aligned sam file\n" . Data::Dumper::Dumper($aligned_record));
            }
            
            my $new_record = $self->_process_record_pair($input_record, $aligned_record, $reference_build, $methylation_mapping, $chrFhs);
            
            # TODO need to fix flags?
            # in force fragment mode, you could figure out flags 0x1, 0x40, and 0x80
            # but could not figure out flags 0x2, 0x8, and 0x20
            # either way i don't think you'd want to set these, since it's assumed they won't be set running in se mode?

            $self->_print_record_to_fh($outFh, $new_record);
        }
        $inFh->close();
        $alignedFh->close();
    }
    
    my @chrFiles = map {
        $chrFhs->{handles}{$_}->close();
        sprintf("%s/%s.sam", $chrFhs->{basename}, $_);
    } sort {ncmp($a, $b)} keys %{$chrFhs->{handles}};
    
    return \@chrFiles;
}

sub _process_record_pair {
    my $self = shift;
    my $input_record = shift;
    my $aligned_record = shift;
    my $reference_build = shift;
    my $methylation_mapping = shift;
    my $chrFhs = shift;
    
    my $trimmed_seq = $aligned_record->{seq};
    my $trimmed_pos = $aligned_record->{pos};
    my $full_seq = $input_record->{seq};
    
    # verify we're dealing with the same sequence id
    die $self->error_message("Seq id $input_record->{qname} did not match aligned qname $aligned_record->{qname}")
        unless $input_record->{qname} eq $aligned_record->{qname};
    
    # if the sequence was mapped as reverse complemented, complement our INPUT sequence
    if ($self->_query_flag($aligned_record, 'seq_reverse_complemented')) {
        $full_seq = $self->_seq_reverse_complement($full_seq);
    }
    
    # if the read was mapped, and we're running methratio.py, put the unfixed aligned read into a separate sam file
    if ($methylation_mapping and not $self->_query_flag($aligned_record, 'fragment_unmapped')) {
        my $rname = $aligned_record->{rname};
        unless (exists $chrFhs->{handles}{$rname}) {
            my $filename = sprintf("%s/%s.sam", $chrFhs->{basename}, $rname);
            my $fh = IO::File->new(">$filename") || die $self->error_message("Can't open '$filename' for writing.\n");
            for (@{$chrFhs->{headers}}) {
                print $fh $_;
            }
            $chrFhs->{handles}{$rname} = $fh;
        }
        $self->_print_record_to_fh($chrFhs->{handles}{$rname}, $aligned_record);
    }

    # find out how much was clipped
    my $preclip = index($full_seq, $trimmed_seq);
    my $postclip = length($full_seq) - ($preclip + length($trimmed_seq));

    # verify that the sequences correspond
    die $self->error_message("Aligned/trimmed sequence was not found as a subsequence of input sequence:\n$trimmed_seq\n$full_seq")
        if $preclip == -1;
    
    # if the read was aligned and trimmed we need to update its aligned position and ref seq tag (if present)
    if (($preclip > 0 or $postclip > 0) and not $self->_query_flag($aligned_record, 'fragment_unmapped')) {
        my $full_pos = $trimmed_pos - $preclip;
        
        if($methylation_mapping) {
            # the tag to pull
            my $regex = '^XR:Z:([ACTG]+)';
            
            my $tags = $aligned_record->{tags};
            
            # verify that one and only one tag exists
            die $self->error_message("Unexpected number of XR:Z tags where we expected one, and only one")
                unless scalar(grep(/$regex/, @{$tags})) == 1;

            # modify that tag in hacky way
            map {
                my $tag = $_;
                if ($tag =~ /$regex/) {
                    my $trimmed_ref_seq = $1;

                    my $full_ref_seq = $reference_build->sequence(
                        $aligned_record->{rname},
                        $full_pos,
                        $full_pos + length($full_seq) - 1
                    );
                    
                    my $refpreclip = -1;
                    
                    do {
                        $refpreclip = index($full_ref_seq, $trimmed_ref_seq, $refpreclip+1);
                    } while ($refpreclip != -1 and $refpreclip < $preclip);
                    
                    if ($refpreclip == -1) { # we did not find trimmed ref seq in full ref seq, but this does not account for N in full ref seq
                        my $trimmed_full_ref_seq = substr($full_ref_seq, $preclip, length($trimmed_ref_seq));
                        print "Found an odd thing, let's hope it doesn't fail:\n$trimmed_full_ref_seq\n$trimmed_ref_seq\n";
                        
                        my @trimmed_full_ref_seq = split("", $trimmed_full_ref_seq);
                        my @trimmed_ref_seq = split("", $trimmed_ref_seq);
                        
                        for (0..$#trimmed_ref_seq) {
                            if (($trimmed_full_ref_seq[$_] ne 'N') and ($trimmed_full_ref_seq[$_] ne $trimmed_ref_seq[$_])) {
                                die $self->error_message("Trimmed ref seq was not found at expected position of $preclip in full ref seq ($refpreclip):\n$trimmed_ref_seq\n$full_ref_seq");
                            }
                        }
                        
                    }
                    
                    $tag = "XR:Z:" . $full_ref_seq;
                }
                $_ = $tag;
            } @{$tags};
            
            # update tags
            $aligned_record->{tags} = $tags;
        }
        
        # update pos
        $aligned_record->{pos} = $full_pos;
    }

    # update cigar, seq, and qual
    $aligned_record->{cigar} = join('', (
        $preclip > 0 ? $preclip . 'S' : '',
        length($trimmed_seq) . 'M',
        $postclip > 0 ? $postclip . 'S' : ''
    ));
    $aligned_record->{seq} = $full_seq;
    $aligned_record->{qual} = $input_record->{qual};
    
    # if paired end we'll need to fix the positioning info on the pair 
    # then we probably need to probe flags
    
    return $aligned_record;
}

sub _query_flag {
    my $self = shift;
    my $aligned_record = shift;
    my $query = shift;

    my %flag = (
        multiple_fragments => 0x1,
        both_fragments_aligned => 0x2,
        fragment_unmapped => 0x4,
        next_fragment_unmapped => 0x8,
        seq_reverse_complemented => 0x10,
        next_seq_reverse_complemented => 0x20,
        first_fragment_in_template => 0x40,
        last_fragment_in_template => 0x80,
        secondary_alignment => 0x100,
        not_passing_qual_controls => 0x200,
        pcr_optical_dup => 0x400
    );
    
    return exists $flag{$query} ? $flag{$query} & $aligned_record->{flag} : undef;
}

sub _seq_reverse_complement {
    my $self = shift;
    my $string = shift;

    my %inverse_bp = (
        A => 'T',
        T => 'A',
        C => 'G',
        G => 'C'
    );

    my @oldchars = split("", $string);
    my @newchars;

    while(scalar(@oldchars)) {
        my $curchar = pop @oldchars;
        push @newchars, exists ($inverse_bp{$curchar}) ? $inverse_bp{$curchar} : $curchar;
    }

    return join("", @newchars);
}
sub _print_record_to_fh {
    my $self = shift;
    my $samFh = shift;
    my $record = shift;

    my @keys = qw(qname flag rname pos mapq cigar rnext pnext tlen seq qual);
    chomp (my $line = join("\t", ( (map {$record->{$_}} @keys), @{$record->{'tags'}} ) ));
    #print "[31m" . $line . "[0m\n";
    print $samFh $line."\n";
}

sub _pull_sam_record_from_fh_skip_headers {
    my $self = shift;
    my $samFh = shift;
    
    while(1) {
        my $record = $self->_pull_sam_record_from_fh($samFh);
        
        # return unless we pulled a header
        return $record unless defined($record) and exists($record->{header});
    }
}

sub _pull_sam_record_from_fh {
    my $self = shift;
    my $sam_fh = shift;
    #my $color = shift;
    
    my $line = $sam_fh->getline();
    
    if (not defined $line) {
        return undef;
    } elsif ($line =~ /^@(?:HD|SQ|RG|PG).+?\n/) {
        chomp($line);
        #print "$color$line[0m";
        return {header => $line}
    } else {
        my @fields = split("\t", $line);
        my $record;
        my @keys = qw(qname flag rname pos mapq cigar rnext pnext tlen seq qual);
        for (@keys) {
            $record->{$_} = shift @fields;
        }
        $record->{tags} = \@fields; # the remaing fields should be tags
        #print "$color$line[0m";
        return $record;
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
        return undef;
    } else {
        #print "[35m$fastq_id[0m";
        #print "[35m$fastq_sequence[0m";
        #print "[35m$fastq_qual[0m";
        chomp($fastq_id);
        chomp($fastq_sequence);
        chomp($fastq_qual);
    }
    

    # chop the /1 or /2 from the end of the read id
    $fastq_id =~ /^@(.+?)(?:\/([12]))?$/; # this is probably unnecessary in non pe reads
    $fastq_id = $1;
    my $pair = $2;
    
    return {
        qname => $fastq_id,
        seq => $fastq_sequence,
        qual => $fastq_qual,
        pair => defined($pair) ? $pair : '0'
    };
}

sub _build_sam_index {
    my $self = shift;
    my $samfile = shift;

    my $fh = IO::File->new($samfile) || die $self->error_message("Could not open $samfile to build index of ids");
    
    my %hash;

    my $pos = tell($fh);
    my $last_id = "";

    my $count = 0;

    while(my $line = <$fh>) {
        if (substr($line, 0, 1) eq '@') {
            $pos = tell($fh);
            next;
        }

        my $id = substr $line, 0, index($line, "\t");
        
        if ($id eq $last_id) {
            $pos = tell($fh);
            next;
        } else {
            $last_id = $id;
        }
        
        my @id_parts = split(":", $id);
        my $last_part = pop @id_parts;

        #print Data::Dumper::Dumper(\@id_parts)."\n";
        
        my $cur_hash = \%hash;
        for (@id_parts) {
            if (defined $cur_hash->{$_}) {
                $cur_hash = $cur_hash->{$_};
            } else {
                $cur_hash->{$_} = {};
                $cur_hash = $cur_hash->{$_};
            }
        }
        $count++;
        die if exists($cur_hash->{$last_part});
        $cur_hash->{$last_part} = $pos;
        if ($count % 100000 == 0) {
            print "Indexed $count ids.\n";
        }
        
        $pos = tell($fh);
    }
    
    print "Done! Indexed $count total ids.\n";
    
    $fh->close();
    
    return \%hash;
}

sub _pull_id_pos_from_index {
    my $self = shift;
    my $index = shift;
    my $id = shift;

    my @id_parts = split(":", $id);

    my $last_part = pop @id_parts;

    my $cur_hash = $index;
    for (@id_parts) {
        if (defined $cur_hash->{$_}) {
            $cur_hash = $cur_hash->{$_};
        } else {
            die $self->error_message("Index error pulling $id.");
        }
    }
    return $cur_hash->{$last_part};
}

# TODO
# verify above flags (fillmd, rg addition, bam i/o)
# sam flags are probably correct, probably don't need to change anything for ff
# however ff mode would probably crash when running with input bams; ask ben
# cigar string with =/X doesnt work
# insert sizes
# log files and last minute checks
# methratio.py is not installed
