package Genome::Model::Tools::BioSamtools::ParallelRefCov;

use strict;
use warnings;

use Genome;
use Workflow;

class Genome::Model::Tools::BioSamtools::ParallelRefCov {
    is => ['Workflow::Operation::Command','Genome::Model::Tools::BioSamtools'],
    workflow => sub {
        my $workflow = Workflow::Operation->create(
                                                   name => 'bio-samtools parallel ref-cov',
                                                   operation_type => Workflow::OperationType::Command->get('Genome::Model::Tools::BioSamtools::RefCov'),
                                               );
        $workflow->parallel_by('regions_file');
        return $workflow;
    },
    has => [
        regions => { is => 'Number', default_value => 10000 },
        _stats_file => { is_optional => 1, },
    ],
};

sub pre_execute {
    my $self = shift;

    my $regions_file = $self->regions_file;

    my ($bam_basename,$bam_dirname,$bam_suffix) = File::Basename::fileparse($self->bam_file,qw/bam/);
    $bam_basename =~ s/\.$//;
    my ($regions_basename,$regions_dirname,$regions_suffix) = File::Basename::fileparse($self->regions_file,qw/tsv/);
    $regions_basename =~ s/\.$//;
    $self->_stats_file($self->output_directory .'/'. $bam_basename .'_'. $regions_basename .'_STATS.tsv');

    my $regions = $self->regions;
    require Cwd;
    my $cwd = Cwd::cwd();
    chdir $self->output_directory;
    my $sub_regions_basename = $regions_basename .'_SUB_REGIONS';
    Genome::Utility::FileSystem->shellcmd(
                                          cmd => "split -a 4 -d -l $regions $regions_file $sub_regions_basename",
                                          input_files => [$regions_file],
                                      );
    chdir $cwd;
    my @files = glob($self->output_directory .'/'. $sub_regions_basename .'*');
    $self->regions_file(\@files);
    return 1;
}

sub post_execute {
    my $self = shift;

    my @failures = grep { $_ ne 1 } @{$self->result};
    if (@failures) {
        $self->error_message('One or more of the parallel commands failed');
        die($self->error_message);
    }

    Genome::Utility::FileSystem->cat(
        input_files => $self->stats_file,
        output_file => $self->_stats_file,
    );

    for my $file (@{$self->regions_file},@{$self->stats_file}) {
        unless (unlink $file) {
            $self->error_message('Failed to remove file '. $file .":  $!");
            die($self->error_message);
        }
    }
    $self->stats_file($self->_stats_file);
    return 1;
}


1;
