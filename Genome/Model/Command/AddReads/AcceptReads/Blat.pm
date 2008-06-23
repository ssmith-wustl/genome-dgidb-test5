package Genome::Model::Command::AddReads::AcceptReads::Blat;

use strict;
use warnings;

use above "Genome";
use Command;
use Genome::Model;

class Genome::Model::Command::AddReads::AcceptReads::Blat {
    is => [
           'Genome::Model::Command::AddReads::AcceptReads',
       ],
};

sub help_brief {
    "Not sure what criteria will be used here";
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads accept-reads blat --model-id 5 --read-set-id 10
EOS
}

sub help_detail {
    return <<EOS
This command is usually called as part of the add-reads process
EOS
}

sub should_bsub {1;}

sub execute {
    my $self = shift;

    my $model = $self->model;

    # for now everything passes until criteria are determined
    $self->add_metric(name => 'read set pass fail', value => 'pass');

    return 1;
}


1;

