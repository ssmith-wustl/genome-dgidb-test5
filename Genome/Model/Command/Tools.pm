
package Genome::Model::Command::Tools;

use strict;
use warnings;

use above "Genome";
use Command; 

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',
);

sub help_brief {
    "misc tools which are used in conjunction with genome modeling"
}

1;

