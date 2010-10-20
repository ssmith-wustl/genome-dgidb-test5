package EGAP::Command::GenePredictor::tRNAscan;

use strict;
use warnings;

use EGAP;
use File::Temp;
use IO::File;
use Carp 'confess';

class EGAP::Command::GenePredictor::tRNAscan {
    is => 'EGAP::Command::GenePredictor',
    has_optional => [
        domain => {
            is => 'Text',
            is_input => 1,
            valid_values => ['archaeal', 'bacterial', 'eukaryotic'],
            default => 'eukaryotic',
        },
        trnascan_install_path => {
            is => 'Path',
            default => '/gsc/bin/tRNAscan-SE',
            doc => 'Path to program executable',
        },
    ],
};

sub help_brief {
    return "Runs tRNAscan on the provided fasta file";
}

sub help_synopsis {
    return "Runs tRNAscan on the provided fasta file";
}

sub help_detail {
    return <<EOS
Runs tRNAsca on the provided fasta file, places raw output and prediction
output into provided directories
EOS
}

sub execute {
    my $self = shift;

    # Need a unique file name for raw output
    my $raw_output_fh = File::Temp->new(
        DIR => $self->raw_output_directory,
        TEMPLATE => "trnascan_raw_output_XXXXX",
        CLEANUP => 0,
        UNLINK => 0,
    );
    my $raw_output_file = $raw_output_fh->filename;
    $raw_output_fh->close;

    # Construct command and parameters/switches
    my @params;
    push @params, $self->fasta_file;
    push @params, "-B " if $self->domain eq 'bacterial';
    push @params, "-A " if $self->domain eq 'archaeal';
    push @params, "> $raw_output_file ";
    push @params, "2> $raw_output_file.error ";
   
    my $cmd = join(" ", $self->trnascan_install_path, @params);
    $self->status_message("Preparing to run tRNAscan-SE: $cmd");
    
    my $rv = system($cmd);
    confess 'Trouble executing tRNAscan!' unless defined $rv and $rv == 0;

    # Parse output and create UR objects
    $raw_output_fh = IO::File->new($raw_output_file, 'r');
    for (1..3) { $raw_output_fh->getline };  # First three lines are headers
    while (my $line = $raw_output_fh->getline) {
        chomp $line;
        my ($seq_name, $trna_num, $begin, $end, $type, $codon, $intron_begin, $intron_end, $score) = split(/\s+/, $line);

        my $strand = 1;
        $strand = -1 if $begin > $end;
        ($begin, $end) = ($end, $begin) if $begin > $end;

        my $sequence = $self->get_sequence_by_name($seq_name);
        confess "Couldn't get sequence $seq_name!" unless $sequence;
        my $seq_string = $sequence->subseq($begin, $end);

        my $rna_gene = EGAP::RNAGene->create(
            directory => $self->prediction_directory,
            gene_name => $seq_name . $trna_num,
            description => $type,
            start => $begin,
            end => $end,
            strand => $strand,
            source => 'trnascan',
            score => $score,
            sequence_name => $seq_string,
            sequence_string => $seq_string,
        );
    }

    my @locks = $self->lock_files_for_predictions(qw/ EGAP::RNAGene /);
    UR::Context->commit;
    $self->release_prediction_locks(@locks);

    $self->status_message("trnascan successfully completed!");
    return 1;
}

1;
