package Genome::Model::GenePrediction::Eukaryotic::MergeFiles;

use strict;
use warnings;
use Genome;

class Genome::Model::GenePrediction::Eukaryotic::MergeFiles {
    is => 'Command',
    has => [
        input_files => {
            is => 'FilePath',
            is_input => 1,
            is_many => 1,
            doc => 'Files to be merged together',
        },
        output_file => {
            is => 'FilePath',
            is_input => 1,
            is_output => 1,
            doc => 'Merged file output file',
        },
    ],
};

sub help_brief { return 'Merges files together' };
sub help_synopsis { return help_brief() };
sub help_detail { return 'Merges files of any format together' };

sub execute {
    my $self = shift;

    my @input_files = grep { -e $_ } $self->input_files;
    $self->status_message("Merging together " . scalar @input_files . " files into " . $self->output_file);

    my $rv = Genome::Sys->cat(
        input_files => \@input_files,
        output_file => $self->output_file,
    );
    unless ($rv) {
        $self->error_message("Could not merge files!");
        return 0;
    }

    return 1;
}

1;

