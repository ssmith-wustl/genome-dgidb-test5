
package Genome::Model::Command::Remove;

use strict;
use warnings;

use above "Genome";
use Command; 
use Data::Dumper;

class Genome::Model::Command::Remove {
    is => 'Genome::Model::Command',
};

sub sub_command_sort_position { 2 }

sub help_brief {
    "remove a genome-model"
}

sub help_synopsis {
    return <<"EOS"
    genome-model remove FooBar
EOS
}

sub help_detail {
    return <<"EOS"
This command deletes the specified genome model.
EOS
}

sub execute {
    my $self = shift;    
    my $model = $self->model;
    my @events = $model->events;
    for (@events) { $_->delete }
    $model->delete;
    return 1;
}

1;

