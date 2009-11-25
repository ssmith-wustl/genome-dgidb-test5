package Genome::Model::Tools::BioSamtools::RefCov;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::BioSamtools::RefCov {
    is => ['Genome::Model::Tools::BioSamtools'],
    has_input => [
        bam_file => { },
        regions_file => { },
        output_directory => { },
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
        my ($bam_basename,$bam_dirname,$bam_suffix) = File::Basename::fileparse($self->bam_file,qw/bam/);
        $bam_basename =~ s/\.$//;

        my ($regions_basename,$regions_dirname,$regions_suffix) = File::Basename::fileparse($self->regions_file,qw/tsv/);
        $regions_basename =~ s/\.$//;
        $self->stats_file($self->output_directory .'/'. $bam_basename .'_'. $regions_basename .'_STATS.tsv');
    }
    my $cmd = $self->execute_path .'/refcov-64.pl '. $self->bam_file .' '. $self->regions_file .' '. $self->stats_file;
    Genome::Utility::FileSystem->shellcmd(
        cmd => $cmd,
        input_files => [$self->bam_file,$self->regions_file],
        output_files => [$self->stats_file],
    );
    return 1;
}

1;
