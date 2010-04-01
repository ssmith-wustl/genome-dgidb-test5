package Genome::Model::Tools::BioSamtools::BamToUnalignedFastq;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::BioSamtools::BamToUnalignedFastq {
    is => ['Genome::Model::Tools::BioSamtools'],
    has_input => [
        bam_file => {
            is => 'Text',
            doc => 'A BAM format file of alignment data(WARNING: needs to be name sorted)'
        },
        output_directory => {
            is => 'Text',
            doc => 'A directory to output s_*_*_sequence.txt files',
        },
    ],
};

sub execute {
    my $self = shift;

    #TODO: Add check to see if BAM is namesorted, if not name sort the BAM first
    my $cmd = $self->execute_path .'/bamToUnalignedFastq.pl '. $self->bam_file .' '. $self->output_directory;
    Genome::Utility::FileSystem->shellcmd(
        cmd => $cmd,
        input_files => [$self->bam_file],
    );
    return 1;
}

1;
