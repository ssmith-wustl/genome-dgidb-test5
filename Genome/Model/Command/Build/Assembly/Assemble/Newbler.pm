package Genome::Model::Command::Build::Assembly::Assemble::Newbler;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::Assembly::Assemble::Newbler {
    is => 'Genome::Model::Command::Build::Assembly::Assemble',
};

sub bsub_rusage {
    return "-R 'select[type=LINUX64]'";
}

sub sub_command_sort_position { 40 }

sub help_brief {
    "assemble a genome"
}

sub help_synopsis {
    return <<"EOS"
genome-model build assembly assemble
EOS
}

sub help_detail {
    return <<"EOS"
One build of a given assembly model.
EOS
}


sub execute {
    my $self = shift;

    $DB::single = $DB::stopper;

    my $model = $self->model;

    my $params = $model->assembler_params || '';

    my %run_project_params = (
			      params => $params,
			      dir => $model->data_directory,
			      version => $model->assembler_version,
			      );

    my $run_project = Genome::Model::Tools::454::Newbler::RunProject->create( %run_project_params );

    unless($run_project->execute) {
        $self->error_message('Failed to run assembly project '. $model->data_directory);
        return;
    }
    my $assembly_dir = $model->data_directory .'/assembly';

    return 1;
}


1;

