package Genome::Model::GenePrediction::Eukaryotic::MergePredictionAceFiles;

use strict;
use warnings;
use Genome;
use Carp 'confess';

class Genome::Model::GenePrediction::Eukaryotic::MergePredictionAceFiles {
    is => 'Command',
    has => [
        ace_file => {
            is => 'FilePath',
            is_input => 1,
            is_output => 1,
            doc => 'Chunks are merged into this file',
        },
        ace_file_chunks => {
            is => 'ARRAY',
            is_input => 1,
            doc => 'An array of ace file chunks to be merged',
        },
    ],
};

sub execute {
    my $self = shift;

    my @ace_file_chunks = @{$self->ace_file_chunks};
    unless (@ace_file_chunks) {
        $self->warning_message("No ace file chunks given, exiting");
        return 1;
    }

    my $ace_file = $self->ace_file;
    if (-e $ace_file) {
        $self->warning_message("Removing existing merged ace file at $ace_file");
        unlink $ace_file;
    }

    my @chunks_with_output;
    for my $chunk (@ace_file_chunks) {
        push @chunks_with_output, $chunk if -s $chunk;
    }

    $self->status_message("Concatenating " . scalar @chunks_with_output . " ace file chunks into $ace_file");

    my $rv = Genome::Sys->cat(
        input_files => @ace_file_chunks,
        output_file => $ace_file,
    );
    confess "Could not concatenate ace files!" unless defined $rv and $rv;

    $self->status_message("Done merging, merged file at $ace_file");
    return 1;
}
1;

