package Genome::Model::Tools::BioSamtools::BamToUnalignedFastq;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::BioSamtools::BamToUnalignedFastq {
    is => ['Genome::Model::Tools::BioSamtools'],
    has_input => [
        bam_file => {
            is => 'Text',
            doc => 'A BAM format file of alignment data.'
        },
        output_directory => {
            is => 'Text',
            doc => 'A directory to output s_*_*_sequence.txt files.  Two files for unmapped pairs and one file for unmapped fragments or unmapped mates whose mate-pair is mapped.',
        },
    ],
};

sub execute {
    my $self = shift;

    my $cmd = $self->execute_path .'/bamToUnalignedFastq.pl '. $self->bam_file .' '. $self->output_directory;
    Genome::Utility::FileSystem->shellcmd(
        cmd => $cmd,
        input_files => [$self->bam_file],
    );
    return 1;
}

1;
