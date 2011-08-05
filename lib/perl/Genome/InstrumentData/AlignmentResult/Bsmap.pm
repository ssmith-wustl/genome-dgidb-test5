package Genome::InstrumentData::AlignmentResult::Bsmap;

use strict;
use warnings;
use IO::File;
use File::Basename;
use File::Copy;
use File::Temp;
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

    #my $rv = $self->_shell_cmd_wrapper(
    my $rv = Genome::Sys->shellcmd(
        cmd => $align_cmd,
        input_files => [@input_pathnames, $reference_fasta_path],
        output_files => [$temp_sam_output]
    );
    unless($rv) { die $self->error_message("Alignment failed."); }
    
    ###################################################
    # run methylation mapping
    ###################################################
    $self->status_message("Running methratio.py.");

    # TODO this may have issues in force fragment mode?
    my $methylation_output = $staging_directory . "/output.meth.dat";
    
    my $meth_cmd = sprintf("/usr/bin/python %s/%s %s > %s",
        #dirname($bsmap_cmd_path), #TODO fix this
        dirname("/gscuser/cmiller/usr/src/bsmap-2.1/methratio.py"),
        "methratio.py",
        $temp_sam_output,
        $methylation_output
    );
    
    $rv = Genome::Sys->shellcmd(
        cmd => $meth_cmd,
        input_files => [$temp_sam_output],
        output_files => [$methylation_output]
    );
    
    ###################################################
    # append temp sam file to all_sequences.sam
    ###################################################
    $self->status_message("Adjusting and appending mapped_reads.sam to all_sequences.sam.");
    
    $self->_fix_sam_output($temp_sam_output, $sam_file, @input_pathnames);
    
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
    # TODO this is not forcing things that should be forced when not provided...
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

sub _process_record_pair {
    my $self = shift;
    my $input_record = shift;
    my $aligned_record = shift;
    my $reference_build = shift;
    
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

    # find out how much was clipped
    my $preclip = index($full_seq, $trimmed_seq);
    my $postclip = length($full_seq) - ($preclip + length($trimmed_seq));

    # verify that the sequences correspond
    die $self->error_message("Aligned/trimmed sequence was not found as a subsequence of input sequence:\n$trimmed_seq\n$full_seq")
        if $preclip == -1;
    
    # if the read was aligned and trimmed we need to update its aligned position and ref seq tag (if present)
    if (($preclip > 0 or $postclip > 0) and not $self->_query_flag($aligned_record, 'fragment_unmapped')) {
        my $full_pos = $trimmed_pos - $preclip;
        
        if($self->decomposed_aligner_params =~ /-R/) {
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
                    
                    if ($trimmed_ref_seq =~ /TGTGTGTGTGTGTGTGTGTGTGTG/) {
                        $DB::single = 1;
                    }

                    my $full_ref_seq = $reference_build->sequence(
                        $aligned_record->{rname},
                        $full_pos,
                        $full_pos + length($full_seq) - 1
                    );
                    
                    my $refpreclip = -1;
                    
                    do {
                        $refpreclip = index($full_ref_seq, $trimmed_ref_seq, $refpreclip+1);
                    } while ($refpreclip != -1 and $refpreclip < $preclip);
                    
                    die $self->error_message("Trimmed ref seq was not found at expected position of $preclip in full ref seq ($refpreclip):\n$trimmed_ref_seq\n$full_ref_seq")
                        if $refpreclip == -1;
                    
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
#
sub _fix_sam_output {
    my $self = shift;
    my $temp_sam_output = shift;
    my $sam_file = shift;
    my @in_files = @_;
    
    my $reference_build = $self->reference_build;

    my $reference_tar_present = $self->decomposed_aligner_params =~ /-R/ ? 1 : 0;
    my $paired_end = scalar(@in_files) == 2 ? 1 : 0;
    my $is_bam = $self->accepts_bam_input();

    my $alignedFh = IO::File->new("$temp_sam_output") || die $self->error_message("Can't open '$temp_sam_output' for reading.\n");
    my $outFh = IO::File->new(">>$sam_file") || die $self->error_message("Can't open '$sam_file' for appending.\n");

    
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
            my @aligned_records = map{$self->_pull_sam_record_from_fh_skip_headers($alignedFh)} (1..2);

            if ((grep{not defined($_)} @input_records) or (grep{not defined($_)} @aligned_records)) {
                if ( (grep{not defined($_)} (@input_records, @aligned_records)) == (@input_records + @aligned_records) ) {
                    last;
                } else {
                    die $self->error_message("A file ended prematurely\n" . Data::Dumper::Dumper([@input_records, @aligned_records]));
                }
            }
            
            my @new_records = (
                $self->_process_record_pair($input_records[0], $aligned_records[0], $reference_build),
                $self->_process_record_pair($input_records[1], $aligned_records[1], $reference_build)
            );
            
            # we need to update the positions of the pair
            $new_records[0]->{pnext} = $new_records[1]->{pos};
            $new_records[1]->{pnext} = $new_records[0]->{pos};
            
            # TODO need to fix flags?

            for my $new_record (@new_records) {
                my @keys = qw(qname flag rname pos mapq cigar rnext pnext tlen seq qual);
                chomp (my $line = join("\t", ( (map {$new_record->{$_}} @keys), @{$new_record->{'tags'}} ) ));
                print $outFh $line."\n";
                #print "[31m" . $line . "[0m\n";
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
            my $aligned_record = $self->_pull_sam_record_from_fh_skip_headers($alignedFh);

            if (not defined($input_record) or not defined($aligned_record)) {
                if (not defined($input_record) and not defined($aligned_record)) {
                    last;
                } elsif (not defined($input_record)) {
                    die $self->error_message("Input file ended prematurely")
                } elsif (not defined($aligned_record)) {
                    die $self->error_message("Aligned sam file ended prematurely");
                } else {
                    die $self->error_message("Something logically impossible just happened");
                }
            }
            
            my $new_record = $self->_process_record_pair($input_record, $aligned_record, $reference_build);
            
            # TODO need to fix flags?
            # in force fragment mode, you could figure out flags 0x1, 0x40, and 0x80
            # but could not figure out flags 0x2, 0x8, and 0x20
            # either way i don't think you'd want to set these, since it's assumed they won't be set running in se mode?

            my @keys = qw(qname flag rname pos mapq cigar rnext pnext tlen seq qual);
            chomp (my $line = join("\t", ( (map {$new_record->{$_}} @keys), @{$new_record->{'tags'}} ) ));
            print $outFh $line."\n";
            #print "[31m" . $line . "[0m\n";
        }
        $inFh->close();
        $alignedFh->close();
    }
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


#        
#        
#
#        my @aligned_records;
#
#        while (scalar(@aligned_records) < $in_count) {
#            my $record = $self->_pull_sam_record_from_fh($alignedFh);
#            if ($record == -1) {
#                # die if we have no more lines to read but we believe there to be another record
#                die $self->error_message("Prematurely reached end of temp sam file") if scalar(@aligned_records) < $in_count;
#                last LINE;
#            }
#            push @aligned_records, $record unless grep {$_ eq 'header'} keys(%{$record});
#        }
#        
#        my @in_records = $self->accepts_bam_input()
#            ? map{$self->_pull_sam_record_from_fh($_)} @inFhs
#            : map{$self->_pull_fq_record_from_fh($_)} @inFhs;
#        
#        for my $i (0..($in_count-1)) {
#            if (($aligned_records[$i]->{flag} & 0x10) > 0) {
#                $in_records[$i]->{seq} = $self->_seq_reverse_complement($in_records[$i]->{seq});
#            }
#            my $rv = $self->_calculate_new_cigar_string_and_pos(
#                $reference_build,
#                $aligned_records[$i]->{cigar},
#                $aligned_records[$i]->{rname},
#                $aligned_records[$i]->{pos},
#                $aligned_records[$i]->{seq},
#                $in_records[$i]->{seq},
#                0
#            );
#            
#            $DB::single=1;
#            
#            # we need to fix our tags if there was trimming action
#            if ($reference_tag_present and (length($aligned_records[$i]->{seq}) != length($in_records[$i]->{seq}))) {
#                my $modified_tag_count = 0;
#                map {
#                    my $tag = $_;
#                    if ($tag =~ /^XR:Z:([ACTG]+)/) {
#                        $modified_tag_count++;
#                        die $self->error_message("Modified too many XR:Z tags for this aligned sam line") if $modified_tag_count > 1;
#
#                        my $trimmed_ref_seq = $1;
#                        my $ref_seq = $reference_build->sequence(
#                            $aligned_records[$i]->{rname},
#                            $rv->{pos},
#                            $rv->{pos} + length($in_records[$i]->{seq}) - 1
#                        );
#                        
#                        die $self->error_message("Trimmed reference sequence did not line up with full reference sequence")
#                            if ($aligned_records[$i]->{pos} - index($ref_seq, $trimmed_ref_seq) != $rv->{pos});
#                        
#                        $tag = "XR:Z:" . $ref_seq;
#                    }
#                    $_ = $tag;
#                } @{$aligned_records[$i]->{tags}};
#            }
#
#            $aligned_records[$i]->{cigar} = $rv->{cigar};
#            $aligned_records[$i]->{pos} = $rv->{pos};
#            $aligned_records[$i]->{seq} = $in_records[$i]->{seq};
#            $aligned_records[$i]->{qual} = $in_records[$i]->{qual};
#        }
#        
#        # fix shifted positions on modified paired-end records
#        if ($in_count == 2) {
#            $aligned_records[0]->{pnext} = $aligned_records[1]->{pos};
#            $aligned_records[1]->{pnext} = $aligned_records[0]->{pos};
#        }
#        
#        # if we're not running in PE mode, we may still be in force fragment mode
#        # in this case we need to update the read names so they don't contain the /1 and /2
#        # and also update the sam flags (see TODO below)
#        if ($in_count == 1) {
#            if ($aligned_records[0]->{qname} =~ /^(.+)\/([12])$/) {
#                my $new_qname = $1;
#                my $strand = $2;
#                
#                my $new_flag = $aligned_records[0]->{flag};
#                
#                my %strand_flag_map = (
#                    1 => 0x40,
#                    2 => 0x80
#                );
#
#                $new_flag |= 0x1; # template has multiple fragments
#                $new_flag |= $strand_flag_map{$strand}; # set whether first or last fragment in sequence
#                
#                $aligned_records[0]->{qname} = $new_qname;
#                $aligned_records[0]->{flag} = $new_flag;
#                
#                # TODO flags that may have problems:
#                # 0x2, not clear whether each fragment is properly aligned
#                # 0x8, not clear whether next fragment is unmapped 
#                # 0x20, not clear whether SEQ of next fragment is reverse complemented
#            }
#        }
#        
#        for my $aligned_record (@aligned_records) {
#            my @keys = qw(qname flag rname pos mapq cigar rnext pnext tlen seq qual);
#            chomp (my $line = join("\t", ( (map {$aligned_record->{$_}} @keys), @{$aligned_record->{'tags'}} ) ));
#            print $outFh $line."\n";
#            #if ($in_count == 1) {
#            #    print "[34m" . $line . "[0m\n";
#            #} else {
#            #    print "[31m" . $line . "[0m\n";
#            #}
#        }
#    }
#    
#    die $self->error_message("Sam file ended before input file(s)") if (grep {defined($_->getline())} @inFhs);
#    
#    map{$_->close() || die $self->error_message("Could not close file handle")} (@inFhs, $alignedFh, $outFh);
#}


#sub _calculate_new_cigar_string_and_pos {
#    } elsif ($explicit_mismatch_in_cigar) { # mapped read, convert from 10M to 4=1X5= # TODO this fails in samtools
#        # get the length of our trimmed read
#        my $trimmed_length = length($trimmed_seq);
#
#        # get the reference seq at the mapping location
#        my $reference_seq = $reference_build->sequence($trimmed_seq_rname, $trimmed_seq_pos, $trimmed_seq_pos + $trimmed_length - 1);
#        
#        # go through the trimmed seq and reference seq 1 bp at a time to determine what differs
#        my @trimmed_bps = split("",$trimmed_seq);
#        my @reference_bps = split("",$reference_seq);
#        die "Trimmed and reference sequences had different length during cigar clean up" if (scalar(@trimmed_bps) != scalar(@reference_bps));
#        
#        my @comparison_bps;
#        for (0..($trimmed_length-1)) {
#            push @comparison_bps, $trimmed_bps[$_] eq $reference_bps[$_] ? '=' : 'X';
#        }
#        
#        # now create a cigar string using this info
#        my @cur_bps;
#        
#        while (scalar(@comparison_bps)) {
#            my $cur_bp = shift(@comparison_bps);
#            if (scalar(@cur_bps) > 0 && $cur_bps[$#cur_bps] ne $cur_bp ) {
#                $updated_cigar .= scalar(@cur_bps) . $cur_bps[0];
#                undef(@cur_bps);
#            }
#            push(@cur_bps, $cur_bp);
#        }
#        $updated_cigar .= scalar(@cur_bps) . $cur_bps[0];
#    }
#}

# TODO need this?
sub fillmd_for_sam {
    return 1;
}

# TODO assume yes?
sub requires_read_group_addition {
    return 1;
}

# TODO i'm guessing yes!
sub accepts_bam_input {
    return 1;
}

# TODO it writes to sam but we want to much with the sam before returning so no
sub supports_streaming_to_bam {
    return 0;
}

# TODO
# verify above flags (fillmd, rg addition, bam i/o)
# sam flags may be wrong in force fragment
# cigar string with =/X doesnt work
# insert sizes
# log files and last minute checks
