
# Rename the final word in the full class name <---
package Genome::Model::Command::Tools::AlignReads;

use strict;
use warnings;

use above "Genome";
use Command;

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',
);

sub help_brief {
    "run a variety of alignment tools directly"
}

1;

