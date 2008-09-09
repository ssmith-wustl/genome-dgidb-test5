
# Rename the final word in the full class name <---
package Genome::Model::Tools::Reads::454;

use strict;
use warnings;

use Genome;
use Command;

UR::Object::Type->define(
    class_name => __PACKAGE__,
    is => 'Command',
);

sub help_brief {
    "add 454 reads to a genome model"
}

sub help_detail {                           # This is what the user will see with --help <---
    return <<EOS 


EOS
}

1;

