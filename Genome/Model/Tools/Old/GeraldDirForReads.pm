package Genome::Model::Tools::Old::GeraldDirForReads;

use strict;
use warnings;

use Genome;
use Command;
use GSCApp;

UR::Object::Type->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => [
        mapfile => { is => 'String', doc => 'the maq map file pathname' },
        
    ],
);

sub help_brief {
    "Find the original fastq file for reads in the given maq map file";
}

sub help_detail {                           # This is what the user will see with --help <---
    return <<EOS 
EOS
}


sub execute {
    my $self = shift;

$DB::single = $DB::stopper;
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
        my %node;
        @node{@column_order} = @line;

        my $read_name = $node{'read_name'};  # names look like HWI-EAS97__11840_6_111_374_897
        my($instrument,$run_id,$flow_cell_id,$lane,@stuff) = split('_',$read_name);

        print $read_name," ";

        my $solexa_run = GSC::Equipment::Solexa::Run->get(flow_cell_id => $flow_cell_id);
        unless ($solexa_run) {
            print "No solexa run record for flow cell $flow_cell_id\n";
            next;
        }

        my $base_call_pse = GSC::PSE->get($solexa_run->creation_event_id);
        unless ($base_call_pse) {
            print "No base call pse related to solexa run PSE ".$solexa_run->creation_event_id."\n";
            next;
        }

        # Find the right configure alignment PSE that goes with this lane

        #my config_alignment_pse_for_lane =
        #              map { my $pse = $_; map { $_ => $pse } $pse->added_param('lanes')}
        #              grep { $_->process_to eq 'configure alignment' }
        #              $base_call_pse->get_subsequent_pses_recurse;

        my @config_alignment_pses = grep { $_->process_to eq 'configure alignment' }
                                         $base_call_pse->get_subsequent_pses_recurse;
 
        unless (@config_alignment_pses) {
            print "No 'configure alignment' PSE for flow cell $flow_cell_id lane $lane\n";
            next;
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
            print "Couldn't determing 'configure alignment' PSE related to pse ".$base_call_pse->pse_id.
                  " for flow cell $flow_cell_id lane $lane\n";
            next;
        }

        my @run_alignment_pses = grep { $_->process_to eq 'run alignment' }
                                      $config_alignment_pse->get_subsequent_pses_recurse;
        if (@run_alignment_pses != 1) {
            print "Found ",scalar(@run_alignment_pses)," 'run alignment' PSEs related to pse $base_call_pse for flow cell $flow_cell_id\n";
            next;
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
                next;
            }
            my($from) = $copy_run_pses[0]->added_param('source_directory');
            my($to) = $copy_run_pses[0]->added_param('destination_directory');
            if ($from && $to) {
                $gerald_dir =~ s/$from/$to/;
            } 
        }

        unless (-d $gerald_dir) {
            print "No gerald_directories actually exist\n";
            next;
        }

        my $fasta_pathname = sprintf('%s/s_%d_sequence.txt', $gerald_dir, $lane);
        unless (-f $fasta_pathname) {
            print "Fasta file $fasta_pathname does not exist\n";
            next;
        }
         
        unless (`grep $read_name $fasta_pathname`) {
            print "read $read_name isn't in fasta file $fasta_pathname\n";
            next;
        }

        print "OK $fasta_pathname\n";
    }
}

1;


