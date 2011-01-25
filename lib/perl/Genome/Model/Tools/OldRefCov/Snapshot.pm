package Genome::Model::Tools::OldRefCov::Snapshot;

use strict;
use warnings;

use Genome;
use Workflow;

class Genome::Model::Tools::OldRefCov::Snapshot {
    is => ['Workflow::Operation::Command'],
    workflow => sub {
        my $run = Workflow::Operation->create(
            name => 'run',
            operation_type => Workflow::OperationType::Command->get('Genome::Model::Tools::OldRefCov::Run')
        );
        my $outer = Workflow::Model->create(
            name => 'parallel ref-cov outer',
            input_properties => [@{$run->operation_type->input_properties}],
            output_properties => [@{$run->operation_type->output_properties}],
        );
        $outer->parallel_by('layers_file_path');

        my $inner = Workflow::Model->create(
            name => 'inner',
            input_properties => [@{$outer->operation_type->input_properties}],
            output_properties => [@{$outer->operation_type->output_properties}],
        );
        $inner->workflow_model($outer);
        $run->workflow_model($inner);
        $run->parallel_by('genes_file_path');

        my $merge = $inner->add_operation(
            name => 'merge',
            operation_type => Workflow::OperationType::Command->get('Genome::Model::Tools::OldRefCov::MergeStatsFiles')
        );

        foreach my $in (@{ $inner->operation_type->input_properties }) {
            $inner->add_link(
                left_operation => $inner->get_input_connector,
                left_property => $in,
                right_operation => $run,
                right_property => $in
            );
        }

        $inner->add_link(
            left_operation => $run,
            left_property => 'stats_file_path',
            right_operation => $merge,
            right_property => 'input_stats_files'
        );
        $inner->add_link(
            left_operation => $run,
            left_property => 'layer_stats_file',
            right_operation => $merge,
            right_property => 'output_stats_file'
        );
        $inner->add_link(
            left_operation => $merge,
            left_property => 'result',
            right_operation => $inner->get_output_connector,
            right_property => 'result'
        );

        foreach my $out (@{ $inner->operation_type->output_properties }) {
            next if ($out eq 'result');
            $inner->add_link(
                left_operation => $run,
                left_property => $out,
                right_operation => $inner->get_output_connector,
                right_property => $out
            );
        }

        foreach my $in (@{ $outer->operation_type->input_properties }) {
            $outer->add_link(
                left_operation => $outer->get_input_connector,
                left_property => $in,
                right_operation => $inner,
                right_property => $in
            );
        }

        foreach my $out (@{ $outer->operation_type->output_properties }) {
            $outer->add_link(
                left_operation => $inner,
                left_property => $out,
                right_operation => $outer->get_output_connector,
                right_property => $out
            );
        }
        return $outer;
    },
    has => [
            snapshots => {
                      is => 'Number',
                      doc => 'The number of snapshots to create. defalut_value=8',
                      default_value => 8
                  },
            genes => {
                      is => 'Number',
                      doc => 'The number of reference sequences to parallelize by(zero will use the whole file). default_value=1000',
                      default_value => 1000
                  },
            output_directory => {
                                 calculate_from => ['base_output_directory','unique_subdirectory'],
                                 calculate => q|
                                     return $base_output_directory . $unique_subdirectory;
                                 |
                             },
            unique_subdirectory => {
                            calculate_from => ['layers_file_path'],
                            calculate => q|
                                               my $layers_basename = File::Basename::basename($layers_file_path);
                                               if ($layers_basename =~ /(\d+)$/) {
                                                   return '/'. $1;
                                               } else {
                                                   return '';
                                               }
                                           |,
                        },
        ],
};

sub pre_execute {
    my $self = shift;

    if ($self->snapshots > 1) {
        my $layers_file = $self->layers_file_path;
        my $wc_output = `wc -l $layers_file`;
        chomp($wc_output);
        my ($reads,undef) = split(/\s/,$wc_output);
        #TODO: Do we worry about the remainder if the total reads is not divisible by the number of snapshots
        my $reads_per_snapshot = int($reads / $self->snapshots);

        my $lock = Genome::Sys->lock_resource(resource_lock => $self->output_directory .'/lock_resource_layers');
        my @files = glob($self->output_directory .'/LAYERS*');
        unless (@files) {
            eval {
                require Cwd;
                my $cwd = Cwd::cwd();
                chdir $self->output_directory;
                Genome::Sys->shellcmd(
                                                      cmd => "split -d -l $reads_per_snapshot $layers_file LAYERS",
                                                      input_files => [$layers_file],
                                                  );
                chdir $cwd;
            };
            if ($@) {
                Genome::Sys->unlock_resource(resource_lock => $lock);
                die($@);
            }
            @files = glob($self->output_directory .'/LAYERS*');
        }
        Genome::Sys->unlock_resource(resource_lock => $lock);
        unless (@files) {
            $self->error_message('Failed to create the layers file paths!');
            die($self->error_message);
        }
        $self->layers_file_path(\@files);
    }

    if ($self->genes > 0) {
        my $genes_file = $self->genes_file_path;
        my $genes = $self->genes;
        my $lock = Genome::Sys->lock_resource(resource_lock => $self->output_directory .'/lock_resource_genes');
        my @files = glob($self->output_directory .'/GENES*');
        unless (@files) {
            eval {
                require Cwd;
                my $cwd = Cwd::cwd();
                chdir $self->output_directory;
                Genome::Sys->shellcmd(
                                                      cmd => "split -d -l $genes $genes_file GENES",
                                                      input_files => [$genes_file],
                                                  );
                chdir $cwd;
            };
            if ($@) {
                Genome::Sys->unlock_resource(resource_lock => $lock);
                die($@);
            }
            @files = glob($self->output_directory .'/GENES*');
        }
        Genome::Sys->unlock_resource(resource_lock => $lock);
        unless (@files) {
            $self->error_message('Failed to create the genes file paths!');
            die($self->error_message);
        }
        $self->genes_file_path(\@files);
    }

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
    if ($self->snapshots > 1) {
        for my $layers_file_path (@{$self->layers_file_path}) {
            unlink $layers_file_path || die ('Failed to remove intermediate layers file path '. $layers_file_path .":  $!");
        }
        for my $log_file_path (@{$self->log_file_path}) {
            unlink $log_file_path || die ('Failed to remove log file path '. $log_file_path .":  $!");
        }
        #TODO: write a ref-cov tool to create a composite from each snapshot/lane

        #Not sure about order, etc. maybe just parse the subdir from the layers file name again??
        #my @output_directory = @{$output_directory};

    }
    if ($self->genes > 0) {
        for my $genes_file_path (@{$self->genes_file_path}) {
            unlink $genes_file_path || die ('Failed to remove intermediate genes file path '. $genes_file_path .":  $!");
        }
    }
    for my $stats_file_path (@{$self->stats_file_path}) {
        unlink $stats_file_path || die ('Failed to remove intermediate stats file path '. $stats_file_path .":  $!");
    }
    return 1;
}


1;
