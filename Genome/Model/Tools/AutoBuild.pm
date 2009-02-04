package Genome::Model::Tools::AutoBuild;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::AutoBuild { is => 'Command', };

sub sub_command_sort_position { 24 }

sub help_brief {
"Tool to build solexa reference-alignment genome models that are configured for automatic processing"
      ,;
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gt auto-build ...
EOS
}

sub help_detail {
    return <<EOS
EOS
}

sub execute {
    my $self = shift;

    #needed to get around a UR bug that tony is working on - je
    Genome::Model::ReferenceAlignment->get();


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
