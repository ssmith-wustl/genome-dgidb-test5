package EGAP::Command::GetFastaFiles;

use strict;
use warnings;

use EGAP;

use Bio::SeqIO;
use Bio::Seq;

use Carp 'confess';
use File::Path 'make_path';
use POSIX 'ceil';

class EGAP::Command::GetFastaFiles {
    is => 'EGAP::Command',
    has => [
        seq_set_id => { 
            is => 'Number',
            is_input => 1,
            doc => 'Identifies an assembly in the EGAP database',
        },
        output_directory => {
            is => 'Path',
            is_input => 1,
            doc => 'All split fastas are put in this directory',
        },
    ],
    has_optional => [
        max_bases_per_file => {
            is => 'Number',
            is_input => 1,
            default => 5000000,
            doc => 'Each split fasta should contain approximately this number of bases of sequence each',
        },
        fasta_files => { 
            is => 'ARRAY',
            is_output => 1,
            doc => 'Array of fasta files each containing a single contig from assembly',
        },

    ],
};

sub help_brief {
    return "Splits up an assembly into several smaller fastas";
}

sub help_synopsis {
    return "Splits up an assembly into several smaller fastas";
}

sub help_detail {
    return <<EOS
A given assembly (currently grabbed using the sequence set id, but this will change soon) is split up
into several smaller fastas (by either supercontig or contig), where each fasta file contains no more
than the given number bases.
EOS
}

sub execute {
    my $self = shift;

    $DB::single = 1;
    my $output_directory = $self->output_directory;
    unless (-d $output_directory) {
        my $mkdir_rv = make_path($output_directory);
        confess "Could not make directory at $output_directory" unless $mkdir_rv;
    }

    my $seq_set_id = $self->seq_set_id;
    my $sequence_set = EGAP::SequenceSet->get($seq_set_id);
    my @sequences = $sequence_set->sequences();

    $self->status_message("Found " . scalar @sequences . " contigs in database");

    my @filenames;
    my $current_fasta;
    my $counter = 0;
    my $total_bases = 0;
    my $upper_limit = $self->max_bases_per_file;

    # Split each contig into a separate fasta file
    for my $sequence (@sequences) {
        my $length = length $sequence->sequence_string();
        my $contig = Bio::Seq->new(
            -seq => $sequence->sequence_string(),
            -id => $sequence->sequence_name(),
        );

        if (not defined $current_fasta or ($total_bases + $length) > $upper_limit) {
            my $filename = $output_directory . "/fasta_$counter.fa";
            $current_fasta = Bio::SeqIO->new(
                -file => ">$filename",
                -format => 'Fasta',
            );

            $counter++;
            $total_bases = 0;
            push @filenames, $filename;
        }

        $current_fasta->write_seq($contig);
        $total_bases += $length;
    }

    $self->status_message("Created " . scalar @filenames . " split fasta files in $output_directory");
    $self->fasta_files(\@filenames);
    return 1;
}
 
1;
