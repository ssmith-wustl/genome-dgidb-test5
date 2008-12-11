package Genome::InstrumentData::Command::List;

use strict;
use warnings;

use Genome;

class Genome::InstrumentData::Command::List {
    is => 'Command',
    is_abstract => 1,
};

############################################

sub help_brief {
    return 'list instrument data';
}

############################################

sub Xcommand_name {
    my $class = ref($_[0]) || $_[0];
    return $class->SUPER::command_name unless $class eq __PACKAGE__;
    return 'genome instrument-data list';
}

sub Xcommand_name_brief {
    my $class = ref($_[0]) || $_[0];
    return $class->SUPER::command_name_brief unless $class eq __PACKAGE__;
    return 'instrument-data';
}

############################################

1;

#$HeadURL$
#$Id$
