package Genome::Model::Tools::Fasta::SortByName;

use strict;
use warnings;
use Genome;

class Genome::Model::Tools::Fasta::SortByName {
    is => 'Command::V2',
    has => [
        input_fasta => {
            is => 'FilePath',
            is_input => 1,
            doc => 'Input fasta file',
        },
    ],
    has_optional => [
        sorted_fasta => {
            is => 'FilePath',
            is_output => 1,
            doc => 'Sorted output fasta',
        },
    ],
    doc => 'Sorts a fasta by sequence name',
};

sub help_detail {
    return 'Sorts the sequences in the provided fasta by name and writes result to another file';
}

sub execute {
    my $self = shift;

    unless (-e $self->input_fasta) {
        Carp::confess "No file found at " . $self->input_fasta;
    }
    my $reader = Genome::Data::Reader->create(
        format => 'fasta',
        file => $self->input_fasta,
    );
    unless ($reader) {
        Carp::confess "Could not create reader for file " . $self->input_fasta;
    }
    my @seqs = $reader->slurp();

    @seqs = sort { $a->sequence_name() cmp $b->sequence_name() } @seqs;

    my $output = $self->sorted_fasta;
    unless ($output) {
        $output = $self->input_fasta . '.sorted';
        $self->status_message("No sorted fasta file provided, defaulting to $output!");
    }
    my $writer = Genome::Data::Reader->create(
        format => 'fasta',
        file => $output,
    );
    unless ($writer) {
        Carp::confess "Could not create writer for file $output";
    }
    $writer->write(@seqs);

    return 1;
}

1;

