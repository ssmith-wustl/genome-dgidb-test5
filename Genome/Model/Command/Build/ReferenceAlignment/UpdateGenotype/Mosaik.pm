package Genome::Model::Command::Build::ReferenceAlignment::UpdateGenotype::Mosaik;

use strict;
use warnings;

use Genome;
use Command;
use Genome::Model;


class Genome::Model::Command::Build::ReferenceAlignment::UpdateGenotype::Mosaik {
    is => [
           'Genome::Model::Command::Build::ReferenceAlignment::UpdateGenotype',
       ],
};

sub help_brief {
    my $self = shift;
    return "empty implementation of " . $self->command_name_brief;
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads update-genotype-probabilities mosaik --model-id 5 --run-id 10
EOS
}

sub help_detail {
    return <<EOS
This command is usually called as part of the add-reads process
EOS
}

sub execute {
    my $self = shift;
    my $model = $self->model;
    $self->error_message("running " . $self->command_name . " on " . $model->name . "!");
    $self->status_message("Model Info:\n" . $model->pretty_print_text);
    return 0;
}

1;

