package Genome::Model::Tools::BioSamtools::Breakdown;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::BioSamtools::Breakdown {
    is => ['Genome::Model::Tools::BioSamtools'],
    has_input => [
        bam_file => { doc => 'BAM format file(s) of alignment data' },
        output_file => { doc => 'The tsv output file' },
    ],
};

sub execute {
    my $self = shift;

    my $cmd = $self->execute_path .'/breakdown-64.pl '. $self->output_file .' '. $self->bam_file;
    Genome::Utility::FileSystem->shellcmd(
        cmd => $cmd,
        input_files => [$self->bam_file],
        output_files => [$self->output_file],
    );
    return 1;
}

1;
