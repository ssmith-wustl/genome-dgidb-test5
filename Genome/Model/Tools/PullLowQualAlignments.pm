package Genome::Model::Command::Tools::PullLowQualAlignments;

use strict;
use warnings;

use above "Genome";
use Command;
use GSCApp;

use IO::File;

UR::Object::Type->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => [
        threshold => { is => 'Integer', doc => 'alignments with a mapping quality or single-end mapping quality lower than this will be pulled' },
        mapfile => { is => 'String', doc => 'the maq map file pathname' },
        output => { is => 'String', doc => 'resultant fastq file pathname' },
    ],
);

sub help_brief {
    "Find reads with low quality alignments";
}

sub help_detail {                           # This is what the user will see with --help <---
    return <<EOS 
Given a maq map file, use mapview to find the reads with low alignment
quality, find the original fastq's they came from and create a new
fastq with just these reads
EOS
}


sub execute {
    my $self = shift;

$DB::single=1;
    my $out_filename = $self->output;
    my $output = IO::File->new(">$out_filename");
    unless ($output) {
        $self->error_message("Can't create output file $output: $!");
        return;
    }

    my $maq;
    my $mapfile = $self->mapfile;
    open($maq, "maq mapview $mapfile |");
    unless ($maq) {
        $self->error_message("Problem running maq");
        return;
    }

    # Each line in the maq output is:
    # read name,
    # chromosome,
    # position,
    # strand,
    # insert size from the outer coorniates of a pair,
    # paired flag,
    # mapping quality,
    # single-end mapping quality,
    # alternative mapping quality,
    # number of mismatches of the best hit,
    # sum of qualities of mismatched bases of the best hit,
    # number of 0-mismatch hits of the first 24bp,
    # number of 1-mismatch hits of the first 24bp on the reference,
    # length of the read,
    # read sequence
    # its quality string
    my @interesting_reads;
    my @column_order = qw(read_name chromosome position strand insert_size paired_flag
                          mapping_qual single_end_mapping_qual alt_mapping_qual
                          num_mismatches qual_sum num_0_mismatch_hits num_1_mismatch_hits
                          read_len sequence qual_string);
    while(<$maq>) {
        chomp;

        my(@line) = split;
        my %read_info;
        @read_info{@column_order} = @line;

        next unless ($read_info{'mapping_qual'} > $self->threshold and
                    $read_info{'single_end_mapping_qual'} > $self->threshold );


        # From this data, we _could_ create a fastq file with the low-quality-aligned 
        # reads.  But since we still need to track down the unaligned (unplaced) reads
        # anyway, go ahead and do it the hard way by tracking down the original read info
        
        # the solexa_analysis table has flow_cell_id's.  Their creation_event_id is
        # a 'configure image analysis and base call' PSE.
        # Go forward in the history to find a 'run alignment' PSE.
        # From a Solexa Analysis/run alignment PSE, there is a gerald_directory PSEParam


        my $read_name = $read_info{'read_name'};  # names look like HWI-EAS97__11840_6_111_374_897
        my($instrument,$run_id,$flow_cell_id,$lane,@stuff) = split('_',$read_name);

        my $fastq_file = $self->_get_fastq_file_for_flow_cell_and_lane($flow_cell_id,$lane);
        unless ($fastq_file) {
            $self->error_message("Unable to find original fastq file for read name $read_name flowcell $flow_cell_id lane $lane");
            next;
        }

        my($sequence,$quality) = $self->_get_fastq_data_for_read($fastq_file, $read_name);
        unless ($sequence && $quality) {
            $self->error_message("Can't find data for read $read_name in fastq $fastq_file");
            next;
        }
        chomp($sequence);
        chomp($quality);
        $output->print("\@$read_name\n$sequence\n\+$read_name\n$quality\n");
    }
    $output->close();

    return 1;
}


# This might be a good candidate for turning into C using an mmap 
sub _get_fastq_data_for_read {
    my($self,$fastq_file,$read_name) = @_;

    my $fh = IO::File->new($fastq_file);
    unless ($fh) {
        $self->error_message("Can't open fastq file $fastq_file: $!");
        return;
    }

    my($sequence,$quality);
    while(<$fh>) {
        if ($_ eq "\@$read_name\n") {
            $sequence = <$fh>;
        } elsif ($_ eq "\+$read_name\n") {
            $quality = <$fh>;
        }
        last if ($sequence && $quality);
    }
    return ($sequence,$quality);
}



sub _get_fastq_file_for_flow_cell_and_lane {
    my($self,$flow_cell_id,$lane) = @_;

    my $solexa_run = GSC::Equipment::Solexa::Run->get(flow_cell_id => $flow_cell_id);
    unless ($solexa_run) {
        $self->error_message("No GSC::SolexaRun found for flow cell $flow_cell_id");
        return;
    }

    my $base_call_pse = GSC::PSE->get($solexa_run->creation_event_id);
    unless ($base_call_pse) {
        $self->error_message("No PSE $base_call_pse for GSC::SolexaRun with flow cell $flow_cell_id");
        return;
    }

    # Find the right configure alignment PSE that goes with this lane

    #my config_alignment_pse_for_lane =
    #              map { my $pse = $_; map { $_ => $pse } $pse->added_param('lanes')}
    #              grep { $_->process_to eq 'configure alignment' }
    #              $base_call_pse->get_subsequent_pses_recurse;

    my @config_alignment_pses = grep { $_->process_to eq 'configure alignment' }
                                     $base_call_pse->get_subsequent_pses_recurse;

    unless (@config_alignment_pses) {
        $self->error_message("No 'configure alignment' PSE for flow cell $flow_cell_id lane $lane");
        return;
    }

    my %config_alignment_pse_for_lane =
                  map { my $pse = $_; map { $_ => $pse } $pse->added_param('lanes')}
                  @config_alignment_pses;

    my $config_alignment_pse;
    if (@config_alignment_pses == 1 and ! (keys %config_alignment_pse_for_lane)) {
        # Old skool steps didn't record the lanes as pse params.  If there's only
        # one config PSE, and no lanes, then assume it's the right one
        $config_alignment_pse = $config_alignment_pses[0];

    } else {
        $config_alignment_pse = $config_alignment_pse_for_lane{$lane};
    }
    unless ($config_alignment_pse) {
        $self->error_message("Couldn't determine 'configure alignment' PSE related to pse " . 
                             $base_call_pse->pse_id. " for flow cell $flow_cell_id lane $lane");
        return;
    }

    my @run_alignment_pses = grep { $_->process_to eq 'run alignment' }
                                  $config_alignment_pse->get_subsequent_pses_recurse;
    if (@run_alignment_pses != 1) {
        $self->error_message("Found " . scalar(@run_alignment_pses) .
                             " 'run alignment' PSEs related to pse $base_call_pse for flow cell $flow_cell_id\n");
        return;
    }

    my($gerald_dir) = $run_alignment_pses[0]->added_param('gerald_directory');
    unless ($gerald_dir) {
        $self->error_message("No gerald_directory param on 'run alignment' PSEs for flow cell $flow_cell_id");
        return;
    }

    # Make the most recent (highest PSEid) copy run first in the list
    my @copy_run_pses = sort { $b->pse_id <=> $a->pse_id }
                        grep { $_->process_to eq 'copy run' }
                             $run_alignment_pses[0]->get_subsequent_pses_recurse();
    if (@copy_run_pses) {
        unless ($copy_run_pses[0]->added_param('source_directory') &&
                $copy_run_pses[0]->added_param('destination_directory')) {

            $self->error_message("No source_directory or destination_directory param on copy run PSE ".$copy_run_pses[0]->pse_id);
            return;
        }
        my($from) = $copy_run_pses[0]->added_param('source_directory');
        my($to) = $copy_run_pses[0]->added_param('destination_directory');
        if ($from && $to) {
            $gerald_dir =~ s/$from/$to/;
        }
    }

    my $fastq_pathname = sprintf('%s/s_%d_sequence.txt', $gerald_dir, $lane);
    return $fastq_pathname;
}

1;


