package Genome::Model::Tools::AutoAddReads;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::AutoAddReads { is => 'Command', };

sub sub_command_sort_position { 23 }

sub help_brief {
"Tool to add reads and build solexa reference-alignment genome models that are configured for automatic processing"
      ,;
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gt auto-add-reads ...
EOS
}

sub help_detail {
    return <<EOS
EOS
}

sub execute {
    my $self = shift;

    foreach my $mod ( Genome::Model::ReferenceAlignment->get() ) {
        my $cmd =
            'genome model add-reads --model-id='
          . $mod->genome_model_id()
          . ' --all';
    }

    foreach my $assign_model (
        Genome::Model::ReferenceAlignment->get( auto_assign_inst_data => 1 ) )
    {
        my $assign_cmd =
            'genome model add-reads --model-id='
          . $assign_model->genome_model_id()
          . ' --all';
        my $assign_result = system($assign_cmd);
    }

    foreach my $build_model (
        Genome::Model::ReferenceAlignment->get( auto_build_alignments => 1 ) )
    {
        my $build_cmd =
          'genome model build schedule-stage --stage-name=alignment --model-id='
          . $build_model->genome_model_id();
        my $build_result = system($build_cmd);

        my $run_jobs_cmd =
          'genome model run-jobs --model-id=' . $build_model->genome_model_id();
        my $run_jobs_result = system($run_jobs_cmd);
    }
    return 1;
}

1;
