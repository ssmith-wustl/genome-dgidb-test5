
package Genome::Model::Command::List;

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
    "list information about genome models and available runs"
}

sub help_synopsis {
    return <<"EOS"
    genome-model list
EOS
}

sub help_detail {
    return <<"EOS"
List items related to genome models.
EOS
}

1;

