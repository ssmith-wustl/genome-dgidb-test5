package Genome::Model::Tools::RefCov::ProgressionInstance;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::RefCov::ProgressionInstance {
    is => 'Command',
    has_input => [
        bam_files => {
            is => 'Array',
            doc => 'A list of bam files to merge and run ref-cov',
        },
        target_query_file => {
            is => 'Text',
            doc => 'a file of query names and coordinates relative to the bam targets',
        },
        output_directory => {
            is => 'Text',
            doc => 'The base output directory for ref-cov files',
        },
    ],
    has_output => [
        stats_file => {
            is => 'String',
            is_optional => 1,
        },
        bias_basename => {
            is => 'String',
            is_optional => 1,
        },
        instance => {
            is => 'String',
            is_optional => 1,
        },
    ],
    has_param => [
        lsf_resource => {
            is_optional => 1,
            default_value => "-R 'select[type==LINUX64]'",
        },
    ],
};

sub create {
    my $class = shift;
    my %params = @_;
    my $bam_files = delete($params{bam_files});
    my $self = $class->SUPER::create(%params);
    return unless $self;
    $self->bam_files($bam_files);
    return $self;
}

sub execute {
    my $self = shift;

    my @bam_files = @{$self->bam_files};
    my $instance = scalar(@bam_files);
    my $merged_bam = Genome::Utility::FileSystem->create_temp_file_path('merged_'. $instance .'.bam');
    my %params = (
        software => 'samtools',
        is_sorted => 1,
        files_to_merge => \@bam_files,
        merged_file => $merged_bam,
    );
    my $merge = Genome::Model::Tools::Sam::Merge->create(%params);
    unless ($merge) {
        $self->error_message('Failed to create bam file merge tool with params '. Data::Dumper::Dumper(%params));
        die($self->error_message);
    }
    unless ($merge->execute) {
        $self->error_message('Failed to execute bam file merge '. $merge->command_name);
        die($self->error_message);
    }
    Genome::Utility::FileSystem->create_directory($self->output_directory);
    $self->instance(scalar(@bam_files));
    $self->stats_file($self->output_directory .'/STATS_'. $self->instance .'.tsv');
    $self->bias_basename($self->output_directory .'/bias_'.$self->instance);
    my $cmd = sprintf("/gscuser/jwalker/svn/TechD/RefCov/bin/refcov-64.pl %s %s %s %s",
                      $merged_bam,
                      $self->target_query_file,
                      $self->stats_file,
                      $self->bias_basename,
                  );
    Genome::Utility::FileSystem->shellcmd(
        cmd => $cmd,
        input_files => [$merged_bam,$self->target_query_file],
        output_files => [$self->stats_file],
    );
    return 1;
}

1;
