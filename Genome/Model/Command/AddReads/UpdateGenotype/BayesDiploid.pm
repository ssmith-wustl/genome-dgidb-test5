package Genome::Model::Command::AddReads::UpdateGenotype::BayesDiploid;

use strict;
use warnings;

use above "Genome";
use Command;
use Genome::Model;

class Genome::Model::Command::AddReads::UpdateGenotype::BayesDiploid {
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
    genome-model add-reads update-genotype bayes-diploid --model-id 5 --ref-seq-id 10
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

