
package Genome::Model::Command::List::Models;

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
    "list all genome-models available for manipulation"
}

sub help_synopsis {
    return <<"EOS"
genome-model list 
EOS
}

sub help_detail {
    return <<"EOS"
Lists all known genome models.
EOS
}

sub execute {
    my $self = shift;
    my @models = Genome::Model->get();
    
    for (@models) {
        print $_->pretty_print_text;
    }

}

1;

