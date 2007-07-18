
package Genome::Model::Command;

use strict;
use warnings;

use UR;
use Command;

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',
);

sub command_name {
    'genome-model' 
}

sub help_brief {
    "Tools for modeling a genome's sequence and features."
}


1;
