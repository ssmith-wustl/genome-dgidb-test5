package Genome::Model::Tools::BioSamtools::RepeatContent;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::BioSamtools::RepeatContent {
    is => ['Genome::Model::Tools::BioSamtools'],
    has_input => [
        bam_file => { doc => 'A BAM format file of alignment data' },
        output_file => { doc => 'A tab delimited RepeatMasker style table' },
    ],
};

sub execute {
    my $self = shift;

    my $cmd = $self->execute_path .'/repeat_content.pl '. $self->bam_file .' '. $self->output_file ;
    Genome::Utility::FileSystem->shellcmd(
        cmd => $cmd,
        input_files => [$self->bam_file],
        output_files => [$self->output_file],
    );
    return 1;
}

1;
