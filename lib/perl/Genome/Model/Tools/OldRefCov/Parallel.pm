package Genome::Model::Tools::OldRefCov::Parallel;

use strict;
use warnings;

use Genome;
use Workflow;

class Genome::Model::Tools::OldRefCov::Parallel {
    is => ['Workflow::Operation::Command','Genome::Model::Tools::OldRefCov'],
    workflow => sub {
        my $workflow = Workflow::Operation->create(
                                                   name => 'parallel ref-cov',
                                                   operation_type => Workflow::OperationType::Command->get('Genome::Model::Tools::OldRefCov::Run'),
                                               );
        $workflow->parallel_by('genes_file_path');
        return $workflow;
    },
    has => [
            genes => { is => 'Number', default_value => 1000 },
        ],
};

sub pre_execute {
    my $self = shift;

    my $genes_file = $self->genes_file_path;
    my $genes = $self->genes;

    require Cwd;
    my $cwd = Cwd::cwd();
    chdir $self->output_directory;
    Genome::Sys->shellcmd(
                                          cmd => "split -l $genes $genes_file GENES",
                                          input_files => [$genes_file],
                                      );
    chdir $cwd;
    my @files = glob($self->output_directory .'/GENES*');
    $self->genes_file_path(\@files);
    return 1;
}

sub post_execute {
    my $self = shift;

    print Data::Dumper->new([$self])->Dump;

    my @failures = grep { $_ ne 1 } @{$self->result};
    if (@failures) {
        $self->error_message('One or more of the parallel commands failed');
        die($self->error_message);
    }

    my $merge = Genome::Model::Tools::OldRefCov::MergeStatsFiles->execute(
                                                                       input_stats_files => $self->stats_file_path,
                                                                       output_stats_file => $self->output_directory .'/STATS.tsv',
                                                                   );
    unless ($merge) {
        $self->error_message('Failed to execute the merge command for stats files');
        die($self->error_message);
    }

    for my $file (@{$self->genes_file_path},@{$self->stats_file_path},@{$self->log_file_path}) {
        unless (unlink $file) {
            $self->error_message('Failed to remove file '. $file .":  $!");
            die($self->error_message);
        }
    }
    return 1;
}


1;
