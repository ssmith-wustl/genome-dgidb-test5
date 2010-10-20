package EGAP::Command::MakeTempPredictionDirectory;

use strict;
use warnings;
use EGAP;
use File::Basename;
use File::Temp 'tempdir';

class EGAP::Command::MakeTempPredictionDirectory {
    is => 'EGAP::Command',
    has => [
        fasta_file => {
            is => 'Path',
            is_input => 1,
            doc => 'Fasta file on which predictors will be run, used to help name temp directory',
        },
        base_prediction_directory => {
            is => 'Path',
            is_input => 1,
            doc => 'Directory in which all predictions will go, temp directory placed here',
        },
    ],
    has_optional => [
        temp_prediction_directory => {
            is => 'Path',
            is_output => 1,
            doc => 'Temporary directory for gene predictions',
        },
    ],
};

sub help_brief {
    return "Creates a temporary directory for gene predictions";
}

sub help_synopsis {
    return "Creates a temporary directory for gene predictions";
}

sub help_detail {
    return "Creates a temporary directory for gene predictions";
}

sub execute {
    my $self = shift;
    $self->status_message("Creating temporary directory for gene predictions in " . $self->base_prediction_directory);
    my $fasta = $self->fasta_file;
    my ($fasta_name) = basename($self->fasta_file);

    my $prediction_base = $self->base_prediction_directory;
    my $temp_dir = tempdir(
        $fasta_name . "_temp_predictions_XXXXX",
        CLEANUP => 0,
        UNLINK => 0,
        DIR => $prediction_base,
    );
    $self->temp_prediction_directory($temp_dir);
    $self->status_message("Temporary directory created at $temp_dir");
    return 1;
}

1;

