package Genome::Model::Tools::BioSamtools::ReadLengthDistribution;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::BioSamtools::ReadLengthDistribution {
    is => 'Genome::Model::Tools::BioSamtools',
    has_input => [
        bam_file => {
            is => 'Text',
            doc => 'A path to a BAM format file of aligned capture reads',
        },
        output_file => {
            is => 'Text',
            doc => 'The output directory to generate peak files',
        },
    ],
};

sub execute {
    my $self = shift;
    my $cmd = $self->execute_path .'/read_length_distribution-64.pl '. $self->bam_file .' > '. $self->output_file;
    Genome::Utility::FileSystem->shellcmd(
        cmd => $cmd,
        input_files => [$self->bam_file],
        output_files => [$self->output_file],
        skip_if_output_is_present => 0,
    );
    return 1;
}

1;
