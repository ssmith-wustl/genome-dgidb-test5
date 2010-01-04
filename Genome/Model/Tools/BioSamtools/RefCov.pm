package Genome::Model::Tools::BioSamtools::RefCov;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::BioSamtools::RefCov {
    is => ['Genome::Model::Tools::BioSamtools'],
    has_input => [
        bam_file => { },
        bed_file => { },
        output_directory => { },
        min_depth_filter => { default_value => 1 },
    ],
    has_output => [
        stats_file => {
            is_optional => 1,
        },
    ],
    has_param => [
        lsf_queue => {
            is_optional => 1,
            default_value => 'long',
        },
        lsf_resource => {
            is_optional => 1,
            default_value => "-R 'select[type==LINUX64]'",
        },
    ],
};

sub execute {
    my $self = shift;

    unless (-e $self->output_directory){
        Genome::Utility::FileSystem->create_directory($self->output_directory);
    }
    unless ($self->stats_file) {
        my ($bam_basename,$bam_dirname,$bam_suffix) = File::Basename::fileparse($self->bam_file,qw/.bam/);

        my ($regions_basename,$regions_dirname,$regions_suffix) = File::Basename::fileparse($self->bed_file,qw/.bed/);
        $self->stats_file($self->output_directory .'/'. $bam_basename .'_'. $regions_basename .'_STATS.tsv');
    }
    my $cmd = $self->execute_path .'/bed_refcov-64.pl '. $self->bam_file .' '. $self->bed_file .' '. $self->stats_file .' '. $self->min_depth_filter;
    Genome::Utility::FileSystem->shellcmd(
        cmd => $cmd,
        input_files => [$self->bam_file,$self->bed_file],
        output_files => [$self->stats_file],
    );
    return 1;
}

1;
