
package Genome::Model::Command::Remove;

use strict;
use warnings;

use UR;
use Command; 
use Data::Dumper;

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',
    has => [
        name    => { is => 'String' },
    ]
);

sub help_brief {
    "remove a genome-model"
}

sub help_synopsis {
    return <<"EOS"
genome-model remove some_name another_name
genome-model remove 12345 yet_another_name 56789
EOS
}

sub help_detail {
    return <<"EOS"
This command deletes the specified genome models.
EOS
}

sub execute {
    my $self = shift;    
    my $name = $self->name;
    my @models = Genome::Model->get(name => $name);
    unless (@models) {
        $self->error_message("No model found named $name");
    } 
    for (@models) {
        $self->status_message("Removing " . $_->name . "(id " . $_->id . ")...");
        $_->delete;
    }

}

1;

