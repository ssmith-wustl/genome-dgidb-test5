
# Rename the final word in the full class name <---
package Genome::Model::Tools::Old::AlignReads;

use strict;
use warnings;

use Genome;
use Command;

UR::Object::Type->define(
    class_name => __PACKAGE__,
    is => 'Command',
);

sub help_brief {
    "run a variety of alignment tools directly"
}

1;

