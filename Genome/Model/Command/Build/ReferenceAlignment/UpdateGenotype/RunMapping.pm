package Genome::Model::Command::AddReads::UpdateGenotype::RunMapping;

use strict;
use warnings;

use Genome;
use Command;
use Genome::Model;


class Genome::Model::Command::AddReads::UpdateGenotype::RunMapping {
    is => [
           'Genome::Model::Command::AddReads::UpdateGenotype',
       ],
};

sub help_brief {
    my $self = shift;
    return "empty implementation of " . $self->command_name_brief;
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads update-genotype-probabilities runMapping --model-id 5 --run-id 10
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
    $self->error_message('Not Implemented: ' . $self->command_name . ' on ' . $model->name);
    return 0;
}

1;

