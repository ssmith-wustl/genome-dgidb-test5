
# Rename the final word in the full class name <---
package Genome::Model::Tools::Reads;

use strict;
use warnings;

use above "Genome";
use Command;

UR::Object::Type->define(
    class_name => __PACKAGE__,
    is => 'Command',
);

sub help_brief {
    "tools to work directly with read data files"
}

1;

