package Genome::Model::Tools::BioSamtools::PeakDetection;

use strict;
use warnings;

use Genome;

my $DEFAULT_NORM_FACTORS = '1,2,3,4,5';

class Genome::Model::Tools::BioSamtools::PeakDetection {
    is => 'Genome::Model::Tools::BioSamtools',
    has_input => [
        bam_file => {
            is => 'Text',
            doc => 'A path to a BAM format file of aligned capture reads',
        },
        normalization_factors => {
            is => 'Text',
            doc => 'A comma separated list of normalization factors to evaluate coverage',
            default_value => $DEFAULT_NORM_FACTORS,
            is_optional => 1,
        },
        output_directory => {
            is => 'Text',
            doc => 'The output directory to generate peak files',
        },
    ],
};

sub execute {
    my $self = shift;
    unless (-d $self->output_directory) {
        unless (Genome::Utility::FileSystem->create_directory($self->output_directory)) {
            die('Failed to create output_directory: '. $self->output_directory);
        }
    }
    my $stdout_file = $self->output_directory .'/peak_detection.out';
    my $cmd = $self->execute_path .'/peak_detection-64.pl '. $self->bam_file .' '. $self->output_directory .' '. $self->normalization_factors .' > '. $stdout_file;
    Genome::Utility::FileSystem->shellcmd(
        cmd => $cmd,
        input_files => [$self->bam_file],
        output_files => [$stdout_file],
        skip_if_output_is_present => 0,
    );
    return 1;
}

1;
