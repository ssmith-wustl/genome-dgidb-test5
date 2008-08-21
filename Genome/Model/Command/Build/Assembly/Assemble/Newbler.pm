package Genome::Model::Command::Build::Assembly::Assemble::Newbler;

use strict;
use warnings;

use above "Genome";

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
    my $run_project = Genome::Model::Tools::454::Newbler::RunProject->create(
                                                                             test => $model->test,
                                                                             dir => $model->assembly_directory,
                                                                         );
    unless($run_project->execute) {
        $self->error_message('Failed to run assembly project '. $model->assembly_directory);
        return;
    }
    return 1;
}


1;

