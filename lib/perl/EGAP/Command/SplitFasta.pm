package EGAP::Command::SplitFasta;

use strict;
use warnings;

use EGAP;
use Carp 'confess';
use Bio::SeqIO;

class EGAP::Command::SplitFasta {
    is => 'Command',
    has => [
        fasta_file => {
            is => 'Path',
            is_input => 1,
            doc => 'Fasta file to be split up',
        },
        output_directory => {
            is => 'Path',
            is_input => 1,
            doc => 'Directory in which split fastas are placed',
        },
    ],
    has_optional => [
        max_bases_per_file => {
            is => 'Number',
            is_input => 1,
            default => 5000000,
            doc => 'Maximum number of bases allowed in each split fasta file',
        },
        fasta_files => {
            is => 'ARRAY',
            is_output => 1,
            doc => 'An array of split fasta files',
        },
        genome_size => {
            is => 'Number',
            is_output => 1,
            doc => 'Total number of bases in given fasta file, might be a useful metric',
        },
    ],
};

sub help_brief {
    return "Splits up a fasta into several chunks";
}

sub help_detail {
    return <<EOS
Given a fasta file, creates several smaller chunks in the given output_directory. Each fasta
chunk is no larger than the given max_bases_per_file parameter.
EOS
}

sub execute {
    my $self = shift;
    my $fasta_file_path = $self->fasta_file;
    unless (-e $fasta_file_path) {
        confess "$fasta_file_path does not exist!";
    }
    unless (-s $fasta_file_path) {
        confess "$fasta_file_path does not have size!";
    }

    my $fasta_file = Bio::SeqIO->new(
        -file => $fasta_file_path,
        -format => 'Fasta',
    );

    my @filenames;
    my $current_fasta;
    my $counter = 0;
    my $current_chunk_size = 0;
    my $total_bases = 0;
    my $upper_limit = $self->max_bases_per_file;
    my $output_directory = $self->output_directory;

    while (my $sequence = $fasta_file->next_seq()) {
        my $length = $sequence->length;

        if (not defined $current_fasta or ($current_chunk_size + $length) > $upper_limit) {
            $total_bases += $current_chunk_size;

            my $filename = $output_directory . "/fasta_$counter.fa";
            $current_fasta = Bio::SeqIO->new(
                -file => ">$filename",
                -format => 'Fasta',
            );

            $counter++;
            $current_chunk_size = 0;
            push @filenames, $filename;
        }

        $current_fasta->write_seq($sequence);
        $current_chunk_size += $length;
    }

    $self->fasta_files(\@filenames);
    $self->genome_size($total_bases);

    return 1;
}
1;

