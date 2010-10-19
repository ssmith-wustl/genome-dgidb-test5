package EGAP::Command::GenePredictor;

use strict;
use warnings;

use EGAP;
use File::Temp;
use File::Basename;
use Bio::SeqIO;

class EGAP::Command::GenePredictor {
    is => 'EGAP::Command',
    is_abstract => 1,
    has => [
        fasta_file => {
            is => 'Path',
            is_input => 1,
            doc => 'Fasta file (possibly with multiple sequences) to be used by predictor',
        },
        raw_output_directory => {
            is => 'Path',
            is_input => 1,
            doc => 'Raw output of predictor goes into this directory',
        },
    ],
};

sub help_brief {
    return 'Abstract base class for EGAP gene prediction modules';
}

sub help_synopsis {
    return 'Abstract base class for EGAP gene prediction modules, defines a few parameters';
}

sub help_detail {
    return 'Abstract base class for EGAP gene prediction modules, defines input and output parameters';
}

# Searches the fasta file for the named sequence and returns a Bio::Seq object representing it.
# TODO This method can be optimized so it isn't necessary to reread the entire fasta file when
# accessing sequences sequentially, which is usually the case when dealing with predictor output.
sub get_sequence_by_name {
    my ($self, $seq_name) = @_;
    my $seq_obj = Bio::SeqIO->new(
        -file => $self->fasta_file,
        -format => 'Fasta',
    );

    while (my $seq = $seq_obj->next_seq()) {
        return $seq if $seq->display_id() eq $seq_name;
    }

    return;
}

1;
