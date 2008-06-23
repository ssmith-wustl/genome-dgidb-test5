package Genome::Model::Command::AddReads::UpdateGenotype::BreakPointRead454;

use strict;
use warnings;

use above "Genome";
use Command;
use Genome::Model;


class Genome::Model::Command::AddReads::UpdateGenotype::BreakPointRead454 {
    is => [
           'Genome::Model::Command::AddReads::UpdateGenotype',
       ],
    has => [
            merged_alignments_file => {via => 'prior_event'},
            merged_fasta_file => {via => 'prior_event'},
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
    $self->status_message('Not Implemented: ' . $self->command_name . ' on ' . $model->name);
    return 1;
}

1;

