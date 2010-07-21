package Genome::Model::Tools::BioSamtools::ErrorRate;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::BioSamtools::ErrorRate {
    is => ['Genome::Model::Tools::BioSamtools'],
    has_input => [
        bam_file => {
            is => 'Text',
            doc => 'A BAM format file of alignment data'
        },
        output_file => {
            is => 'Text',
            doc => 'A file path to store tab delimited output.',
        },
    ],
};

sub execute {
    my $self = shift;
    my $cmd = $self->execute_path .'/error_rate-64.pl '. $self->bam_file .' > '. $self->output_file;
    Genome::Utility::FileSystem->shellcmd(
        cmd => $cmd,
        input_files => [$self->bam_file],
        output_files => [$self->output_file],
    );
    return 1;
}

1;
