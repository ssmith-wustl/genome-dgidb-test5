
package Genome::Model::Tools::Old;

use strict;
use warnings;

use Genome;
use Command; 

UR::Object::Type->define(
    class_name => __PACKAGE__,
    is => 'Command',
);

sub sub_command_sort_position { 1_000_000 }

sub help_brief {
    "(legacy commands which are no longer deployed)"
}

sub help_synopsis {
    return <<"EOS"

svn co \$GSCPAN/perl_modules/trunk perl_modules
cd perl_modules/Genome
genome-model tools old

...
EOS
}

sub help_detail {
    return <<"EOS"
Commands under this namespace are no longer deployed.  Check out the modules from source control to run them for development purposes.
EOS
}

1;

