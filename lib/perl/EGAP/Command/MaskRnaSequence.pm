package EGAP::Command::MaskRnaSequence;

use strict;
use warnings;

use EGAP;
use Carp 'confess';
use File::Temp;
use File::Basename;
use Genome::Utility::FileSystem;

class EGAP::Command::MaskRnaSequence {
    is => 'EGAP::Command',
    has => [
        rna_predictions => {
            is => 'Path',
            is_input => 1,
            doc => 'File containing RnaGene predictions',
        },
        fasta_file => {
            is => 'Path',
            is_input => 1,
            doc => 'Fasta file with sequence that needs masking',
        },
    ],
    has_optional => [
        skip_if_no_rna_file => {
            is => 'Boolean',
            is_input => 1,
            doc => 'If this is set, not finding an rna file is not a fatal error and the masked fasta is the same as the input fasta',
            default => 1,
        },
        masked_fasta_file => {
            is => 'Path',
            is_input => 1,
            is_output => 1,
            doc => 'Fasta file that will contain masked sequence, defaults to fasta_file with a random suffix',
        },
    ],
};

sub help_brief { 
    return "Masks out the sequence associated with RNA predictions from a fasta file";
}

sub help_detail { 
    return "Masks out the sequence associated with RNA predictions from a fasta file";
}

sub execute {
    my $self = shift;

    $self->status_message("Starting rna masking command");

    unless (defined $self->masked_fasta_file) {
        my ($fasta_name, $fasta_dir) = basename($self->fasta_file);
        my $masked_fh = File::Temp->new(
            DIR => $fasta_dir,
            TEMPLATE => $fasta_name . "_rna_masked_XXXXXX",
            CLEANUP => 0,
            UNLINK => 0,
        );
        $self->masked_fasta_file($masked_fh->filename);
        $masked_fh->close;
    }

    unless (-e $self->rna_predictions) {
        if ($self->skip_if_no_rna_file) {
            $self->status_message("No rna predictions file found at " . $self->rna_predictions .
                " and skip_if_no_rna_file flag is set to true. Assuming that no rna predictions were" .
                " made and setting input fasta " . $self->fasta_file . " as masked output fasta!");

            my $cp_rv = Genome::Utility::FileSystem->copy_file($self->fasta_file, $self->masked_fasta_file);
            unless (defined $cp_rv and $cp_rv) {
                confess 'Could not copy input fasta ' . $self->fasta_file . ' to ' . $self->masked_fasta_file . "!";
            }
            return 1;
        }
        else {
            confess 'No rna prediction file found at ' . $self->rna_predictions . '!';
        }
    }

    unless (-e $self->fasta_file) {
        confess 'No fasta file found at ' . $self->fasta_file . '!';
    }
            
    # This pre-loads all the predictions, which makes grabbing predictions per sequence faster below
    $self->status_message("Loading RNAGene objects from file at " . $self->rna_predictions);
    my @rna_predictions = EGAP::RNAGene->get(
        file_path => $self->rna_predictions,
    );

    my $masked_fasta = Bio::SeqIO->new(
        -file => '>' . $self->masked_fasta_file,
        -format => 'Fasta',
    );

    my $fasta = Bio::SeqIO->new(
        -file => $self->fasta_file,
        -format => 'Fasta',
    );

    $self->status_message("Masking sequences in " . $self->fasta_file . " that contain rna prediction stored in " .
            $self->rna_predictions . " and writing to " . $self->masked_fasta_file);

    # Iterate through every sequence in the fasta and find the predictions associated with each one,
    # then mask out sequence associated with an rna prediction
    while (my $seq = $fasta->next_seq()) {
        $self->status_message("Working on sequence " . $seq->display_id());
        my $seq_id = $seq->display_id();
        my $length = $seq->length();
        my $seq_string = $seq->seq();
        
        my @predictions = EGAP::RNAGene->get(
            file_path => $self->rna_predictions,
            sequence_id => $seq_id,
        );

        for my $prediction (@predictions) {
            my $start = $prediction->start;
            my $end = $prediction->end;

            # Make sure that start is less than end and within the bounds of the sequence
            ($start, $end) = ($end, $start) if $start > $end;
            $start = 1 if $start < 1;
            $end = $length if $end > $length;
            $length = ($end - $start) + 1;

            # Any sequence within the rna prediction is replaced with an N
            substr($seq_string, $start - 1, $length, 'N' x $length);
        }

        my $masked_seq = Bio::Seq->new(
            -display_id => $seq_id,
            -seq => $seq_string
        );
        $masked_fasta->write_seq($masked_seq);
    }

    $self->status_message("All sequences have been masked!");
    return 1;
}

1;

