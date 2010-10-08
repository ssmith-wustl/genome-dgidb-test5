package EGAP::Command::FastaToEgapSequence;

use strict;
use warnings;

use EGAP;
use Bio::SeqIO;

class EGAP::Command::FastaToEgapSequence {
    is => 'EGAP::Command',
    has => [
        fasta_file => {
            is => 'Path',
            is_input => 1,
            doc => 'Fasta file to be converted',
        },
        egap_sequence_file => {
            is => 'Path',
            is_input => 1,
            is_output => 1,
            doc => 'File that EGAP sequence objects are written to',
        },
    ],
};

sub help_brief {
    return "Converts a fasta file to EGAP sequence objects";
}

sub help_synopsis {
    return "Converts a fasta file to EGAP sequence objects";
}

sub help_detail {
    return "Converts a fasta file to EGAP sequence objects";
}

sub execute {
    my $self = shift;
    
    $self->status_message("Converting sequence in fasta file " . $self->fasta_file .
        " to EGAP sequence objects stored in " . $self->egap_sequence_file);

    my $fasta = Bio::SeqIO->new(
        -file => $self->fasta_file,
        -format => 'Fasta',
    );

    while (my $seq = $fasta->next_seq()) {
        my $egap_seq = EGAP::Sequence->create(
            file_path => $self->egap_sequence_file,
            sequence_name => $seq->id(),
            sequence_string => $seq->seq(),
        );
    }

    UR::Context->commit;
    $self->status_message("Conversion complete!");
    return 1;
}
1;

