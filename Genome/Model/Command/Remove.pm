
package Genome::Model::Command::Remove;

use strict;
use warnings;

use UR;
use Command; 
use Data::Dumper;

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',
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
    my @names = @{ $self->bare_args };
    my @models = (
        Genome::Model->get(name => \@names),
        Genome::Model->get(id => \@names)
    );
    unless (@models) {
        $self->error_message("No models found matching the specified criteria");
    } 
    for (@models) {
        $self->status_message("Removing " . $_->name . "(id " . $_->id . ")...");
        print $_->delete;
    }

    UR::Context->commit;
}

1;

