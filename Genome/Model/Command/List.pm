
package Genome::Model::Command::List;

use strict;
use warnings;

use above "Genome";
use Command; 
use Data::Dumper;

UR::Object::Type->define(
    class_name => __PACKAGE__,
    is => 'Command',
);

sub sub_command_sort_position { 2 }

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

