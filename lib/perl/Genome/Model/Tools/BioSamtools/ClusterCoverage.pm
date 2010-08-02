package Genome::Model::Tools::BioSamtools::ClusterCoverage;

use strict;
use warnings;

use Genome;

my $DEFAULT_MINIMUM_DEPTHS = '1,5,10,15,20';

class Genome::Model::Tools::BioSamtools::ClusterCoverage {
    is => 'Genome::Model::Tools::BioSamtools',
    has_input => [
        bam_file => {
            is => 'Text',
            doc => 'A path to a BAM format file of aligned capture reads',
        },
        minimum_depths => {
            is => 'Text',
            doc => 'A comma separated list of minimum depths to evaluate coverage',
            default_value => $DEFAULT_MINIMUM_DEPTHS,
            is_optional => 1,
        },
        #minimum_base_quality => {
        #    is => 'Text',
        #    doc => 'A minimum base quality to consider in coverage assesment.  THIS IS DEPRECATED FOR NOW.',
        #    is_deprecated => 1,
        #    default_value => 0,
        #    is_optional => 1,
        #},
        #minimum_mapping_quality => {
        #    is => 'Text',
        #    doc => 'A minimum mapping quality to consider in coverage assesment.  THIS IS DEPRECATED FOR NOW.',
        #    default_value => 0,
        #    is_optional => 1,
        #},
        output_directory => {
            is => 'Text',
            doc => 'The output directory to generate coverage stats',
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
    my $cmd = $self->execute_path .'/cluster_refcov-64.pl '. $self->bam_file .' '. $self->output_directory .' '. $self->min_depth_filter;
    #if ($self->min_base_quality || $self->min_mapping_quality) {
    #    $cmd .= ' '. $self->min_base_quality .' '. $self->min_mapping_quality;
    #}
    Genome::Utility::FileSystem->shellcmd(
        cmd => $cmd,
        input_files => [$self->bam_file],
        #output_files => [$self->stats_file],
    );
    return 1;
}

1;
