package Genome::Model::GenePrediction::Eukaryotic::MergeRepeatMaskerAceFiles;

use strict;
use warnings;
use Genome;

class Genome::Model::GenePrediction::Eukaryotic::MergeRepeatMaskerAceFiles { 
    is => 'Command',
    has => [
        ace_files => {
            is => 'ARRAY',
            is_input => 1,
            doc => 'Array of ace files that need to be merged',
        },
        merged_ace_file => {
            is => 'FilePath',
            is_input => 1,
            doc => 'Location of merged ace file',
        },
    ],
};

sub execute {
    my $self = shift;
    $self->status_message("Concatenating ace files into " . $self->merged_ace_file . "\n" . join("\n", $self->ace_files));
    Genome::Sys->cat(
        input_files => $self->ace_files,
        output_file => $self->merged_ace_file,
    );

    $self->status_message("Done merging! Removing files!");
    unlink $self->ace_files;

    $self->status_message("Files removed, all done here!");
    return 1;
}

1;

