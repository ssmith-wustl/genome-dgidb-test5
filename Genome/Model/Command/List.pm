
package Genome::Model::Command::List;

use strict;
use warnings;

use UR;
use Command; 
use Data::Dumper;
use Term::ANSIColor;

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',
);

sub help_brief {
    "list all genome-models available for manipulation"
}

sub help_synopsis {
    return <<"EOS"

Write a subclass of this.  

Give it a name which is an extension of this class name.

Implement a new viewer for some part  of a genome model.

EOS
}

sub help_detail {
    return <<"EOS"

This module is an abstract base class for commands which resolve coverage.

Subclasses will implement different per-base consensus calling algorithms.  This module
should handle common coverage parameters, typically for handling the results. 

EOS
}

sub execute {
    my $self = shift;
    my @models = Genome::Model->get();
    
    for (@models) {
        $self->print_model($_);
    }

}

sub print_model {
    my $self = shift;
    my $model = shift;

    print Term::ANSIColor::colored("Model: " . $model->name, 'bold red'), "\n\n";
    print Term::ANSIColor::colored("Configured Properties:", 'bold red'), "\n";

    for my $prop (grep {$_ ne "name"} $model->property_names) {
        
        if (defined $model->$prop) {

            print "\t", Term::ANSIColor::colored($prop, 'bold red'), "\t\t",
            Term::ANSIColor::colored($model->$prop, "red"), "\n";
        }
    }

    print "\n\n";
}

1;

