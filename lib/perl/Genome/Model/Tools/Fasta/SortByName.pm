package Genome::Model::Tools::Fasta::SortByName;

use strict;
use warnings;

use Genome;
use Genome::Data::Sorter;

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

    unless ($self->sorted_fasta) {
        $self->sorted_fasta($self->input_fasta . '.sorted');
        $self->status_message("No sorted fasta file provided, defaulting to " . $self->sorted_fasta . "!");
    }

    $self->status_message("Sorting fasta " . $self->input_fasta . " by sequence name and putting results in " . $self->sorted_fasta);

    my $sorter = Genome::Data::Sorter->create(
        input_file => $self->input_fasta,
        output_file => $self->sorted_fasta,
        format => 'fasta',
        sort_by => 'sequence_name',
    );
    $sorter->sort;

    return 1;
}

1;

