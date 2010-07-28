 
package Genome::Model::Tools::Xhong;

use strict;
use warnings;

use Genome;
use Command;

UR::Object::Type->define(
    class_name => __PACKAGE__,
    is => 'Command',
);

sub sub_command_sort_position { 007 }

sub help_brief {
    "(Xin's test stuff)"
}

sub help_synopsis {
    return <<"EOS"

svn co \$GSCPAN/perl_modules/trunk perl_modules
cd perl_modules/Genome
genome-model tools nate

...
EOS
}

sub help_detail {
    return <<"EOS"
	Tools in this directory are Xin\'s test stuff.
EOS
}

1;

