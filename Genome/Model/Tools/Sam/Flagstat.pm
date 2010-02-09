package Genome::Model::Tools::Sam::Flagstat;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Sam::Flagstat {
    is => 'Genome::Model::Tools::Sam',
    has => [
        bam_file => { },
        output_file => { },
    ],
};

sub execute {
    my $self = shift;
    my $cmd = $self->samtools_path .' flagstat '. $self->bam_file .' > '. $self->output_file;
    Genome::Utility::FileSystem->shellcmd(
        cmd => $cmd,
        input_files => [$self->bam_file],
        output_files => [$self->output_file],
    );
    return 1;
}
