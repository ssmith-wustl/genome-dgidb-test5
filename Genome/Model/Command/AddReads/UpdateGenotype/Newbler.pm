package Genome::Model::Command::AddReads::UpdateGenotype::Newbler;

use strict;
use warnings;

use above "Genome";
use Command;
use Genome::Model;


class Genome::Model::Command::AddReads::UpdateGenotype::Newbler {
    is => [
           'Genome::Model::Command::AddReads::UpdateGenotype',
       ],
    has => [ ],
};

sub help_brief {
    my $self = shift;
    return "empty implementation of " . $self->command_name_brief;
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads update-genotype-probabilities newbler --model-id 5 --ref-seq-id all_sequences
EOS
}

sub help_detail {
    return <<EOS
This command is usually called as part of the add-reads process
EOS
}

sub execute {
    my $self = shift;

    $DB::single = 1;

    my $model = $self->model;
    my $run_project = Genome::Model::Tools::Newbler::RunProject->create(
                                                                        dir => $model->alignments_directory,
                                                                        options => $model->genotyper_params;
                                                                    );
    unless ($run_project->execute) {
        $self->error_message('Can not execute runProject on '. $model->alignments_directory
                             .' with params '. $aligner_params);
        return;
    }
    return 1;
}

1;

