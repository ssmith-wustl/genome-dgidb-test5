package Genome::Model::Command::Build::ReferenceAlignment::AlignReads::Crossmatch;

use strict;
use warnings;

use Genome;
use Command;
use Genome::Model;


class Genome::Model::Command::Build::ReferenceAlignment::AlignReads::Crossmatch {
    is => [
           'Genome::Model::Command::Build::ReferenceAlignment::AlignReads',
       ],
    has => [],
};

sub help_brief {
    my $self = shift;
    return "empty implementation of " . $self->command_name_brief;
}

sub help_synopsis {
    return <<"EOS"
    genome-model add-reads align-reads crossmatch --model-id 5 --read-set-id 10
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

