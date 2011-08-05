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
    # append temp sam file to all_sequences.sam
    ###################################################
    $self->status_message("Adjusting and appending mapped_reads.sam to all_sequences.sam.");
    
    $self->_fix_sam_output($reference_build, $temp_sam_output, $sam_file, @input_pathnames);
    
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
    # -R appends refseq information to the bam, allowing us to use a bsmap script to calc methylation ratios
    
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

    $class->status_message("BSMAP doesn't need any index made, doing nothing.");

    return 0;
}

sub _fix_sam_output {
    my $self = shift;
    my $reference_build = shift;
    my $temp_sam_output = shift;
    my $sam_file = shift;
    my @fq_files = @_;
    
    my $inFh = IO::File->new("$temp_sam_output") || die $self->error_message("Can't open '$temp_sam_output' for reading.\n");
    my $outFh = IO::File->new(">>$sam_file") || die $self->error_message("Can't open '$sam_file' for appending.\n");
    my @fqFhs = map{IO::File->new("$_") || die $self->error_message("Can't open '$_' for reading.\n");} @fq_files;
    
    my $fq_count = scalar(@fqFhs);
    
    LINE: while (1) {
        my @sam_records;

        while (scalar(@sam_records) < $fq_count) {
            my $record = $self->_pull_sam_record_from_fh($inFh);
            last LINE if $record == -1;
            push @sam_records, $record unless grep {$_ eq 'header'} keys(%{$record});
        }
        
        my @fq_records = map{$self->_pull_fq_record_from_fh($_)} @fqFhs;
        
        for (0..($fq_count-1)) {
            if (($sam_records[$_]->{flag} & 0x10) > 0) {
                $fq_records[$_]->{seq} = $self->_seq_reverse_complement($fq_records[$_]->{seq});
            }
            my $rv = $self->_calculate_new_cigar_string_and_pos(
                $reference_build,
                $sam_records[$_]->{cigar},
                $sam_records[$_]->{rname},
                $sam_records[$_]->{pos},
                $sam_records[$_]->{seq},
                $fq_records[$_]->{seq},
                0
            );
            $sam_records[$_]->{cigar} = $rv->{cigar};
            $sam_records[$_]->{pos} = $rv->{pos};
            $sam_records[$_]->{seq} = $fq_records[$_]->{seq};
            $sam_records[$_]->{qual} = $fq_records[$_]->{qual};
        }
        
        # if we're not running in PE mode, we may still be in force fragment mode
        # in this case we need to update the read names so they don't contain the /1 and /2
        # and also update the sam flags (see TODO below)
        if ($fq_count == 1) {
            if ($sam_records[0]->{qname} =~ /^(.+)\/([12])$/) {
                my $new_qname = $1;
                my $strand = $2;
                
                my $new_flag = $sam_records[0]->{flag};
                
                my %strand_flag_map = (
                    1 => 0x40,
                    2 => 0x80
                );

                $new_flag |= 0x1; # template has multiple fragments
                $new_flag |= $strand_flag_map{$strand}; # set whether first or last fragment in sequence
                
                $sam_records[0]->{qname} = $new_qname;
                $sam_records[0]->{flag} = $new_flag;
                
                # TODO flags that may have problems:
                # 0x2, not clear whether each fragment is properly aligned
                # 0x8, not clear whether next fragment is unmapped 
                # 0x20, not clear whether SEQ of next fragment is reverse complemented
            }
        }
        
        for my $sam_record (@sam_records) {
            my @keys = qw(qname flag rname pos mapq cigar rnext pnext tlen seq qual);
            chomp (my $line = join("\t", ( (map {$sam_record->{$_}} @keys), @{$sam_record->{'tags'}} ) ));
            print $outFh $line."\n";
            #if ($fq_count == 1) {
            #    print "[34m" . $line . "[0m\n";
            #} else {
            #    print "[31m" . $line . "[0m\n";
            #}
        }
    }
    
    die $self->error_message("Sam file ended before fq file(s)") if (grep {defined($_->getline())} @fqFhs);
    
    map{$_->close() || die $self->error_message("Could not close file handle")} (@fqFhs, $inFh, $outFh);
}

sub _seq_reverse_complement {
    my $self = shift;
    my $string = shift;

    my %map = (
        A => 'T',
        T => 'A',
        C => 'G',
        G => 'C',
        N => 'N'
    );

    my @oldchars = split("", $string);
    my @newchars;

    while(scalar(@oldchars)) {
        push @newchars, $map{pop @oldchars};
    }

    return join("", @newchars);
}

sub _calculate_new_cigar_string_and_pos {
    my $self = shift;
    my $reference_build = shift;
    my $base_cigar = shift;
    my $trimmed_seq_rname = shift;
    my $trimmed_seq_pos = shift;
    my $trimmed_seq = shift;
    my $full_seq = shift;
    my $explicit_mismatch_in_cigar = shift;
    
    my $updated_cigar = "";
    
    if ($base_cigar eq "*") { # unmapped read, convert from * to 10M
        $updated_cigar = length($trimmed_seq) . "M";
    } elsif ($explicit_mismatch_in_cigar) { # mapped read, convert from 10M to 4=1X5= # TODO this fails in samtools
        # get the length of our trimmed read
        my $trimmed_length = length($trimmed_seq);

        # get the reference seq at the mapping location
        my $reference_seq = $reference_build->sequence($trimmed_seq_rname, $trimmed_seq_pos, $trimmed_seq_pos + $trimmed_length - 1);
        
        # go through the trimmed seq and reference seq 1 bp at a time to determine what differs
        my @trimmed_bps = split("",$trimmed_seq);
        my @reference_bps = split("",$reference_seq);
        die "Trimmed and reference sequences had different length during cigar clean up" if (scalar(@trimmed_bps) != scalar(@reference_bps));
        
        my @comparison_bps;
        for (0..($trimmed_length-1)) {
            push @comparison_bps, $trimmed_bps[$_] eq $reference_bps[$_] ? '=' : 'X';
        }
        
        # now create a cigar string using this info
        my @cur_bps;
        
        while (scalar(@comparison_bps)) {
            my $cur_bp = shift(@comparison_bps);
            if (scalar(@cur_bps) > 0 && $cur_bps[$#cur_bps] ne $cur_bp ) {
                $updated_cigar .= scalar(@cur_bps) . $cur_bps[0];
                undef(@cur_bps);
            }
            push(@cur_bps, $cur_bp);
        }
        $updated_cigar .= scalar(@cur_bps) . $cur_bps[0];
    } else { # mapped read, use 10M
        $updated_cigar = $base_cigar;
    }

    # calculate how much was soft clipped from beginning and end
    my $pre_clip = index($full_seq, $trimmed_seq);
    die $self->error_message("Fq sequence not found in sam sequence") unless $pre_clip != -1;
    
    my $post_clip = length($full_seq) - length($trimmed_seq) - $pre_clip;
    
    # return updated cigar string with pre- and post- softclips
    # and the new sequence position
    
    my $full_seq_pos = $trimmed_seq_pos - ($pre_clip > 0 ? $pre_clip : 0);

    return {
        pos => $full_seq_pos,
        cigar => join("", (
            $pre_clip > 0 ? $pre_clip . "S" : "",
            $updated_cigar,
            $post_clip > 0 ? $post_clip . "S" : ""
        ))
    };
}

sub _pull_sam_record_from_fh {
    my $self = shift;
    my $sam_fh = shift;
    
    my $line = $sam_fh->getline();
    #print "[32m$line[0m";
    
    if (not defined $line) {
        return -1;
    } elsif ($line =~ /^@(?:HD|SQ|RG|PG).+?\n/) {
        chomp($line);
        return {header => $line}
    } else {
        my @fields = split("\t", $line);
        my $record;
        my @keys = qw(qname flag rname pos mapq cigar rnext pnext tlen seq qual);
        for (@keys) {
            $record->{$_} = shift @fields;
        }
        $record->{'tags'} = \@fields; # the remaing fields should be tags
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

    #print "[35m$fastq_id[0m";
    #print "[35m$fastq_sequence[0m";
    #print "[35m$fastq_qual[0m";
    
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
        seq => $fastq_sequence,
        qual => $fastq_qual,
        pair => defined($pair) ? $pair : '0'
    };
}

# TODO need this?
sub fillmd_for_sam {
    return 1;
}

# TODO assume yes?
sub requires_read_group_addition {
    return 1;
}

# TODO i'm guessing no
sub accepts_bam_input {
    return 0;
}

# TODO investigate this further:
sub supports_streaming_to_bam {
    return 0;
}

# TODO
# verify above flags (fillmd, rg addition, bam i/o)
# sam flags may be wrong in force fragment
# cigar string with =/X doesnt work
# insert sizes
# log files and last minute checks
