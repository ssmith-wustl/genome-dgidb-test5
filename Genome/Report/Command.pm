package Genome::Report::Command;

use strict;
use warnings;

use Genome;
      
class Genome::Report::Command {
    is => 'Command',
    doc => 'work with reports',
};

############################################

sub help_brief {
    my $class = ref($_[0]) || $_[0];
    return $class->get_class_object->doc if not $class or $class eq __PACKAGE__;
    my ($func) = $class =~ /::(\w+)$/;
    return sprintf('%s a report', ucfirst($func));
}

sub help_detail {
    return help_brief(@_);
}

sub command_name {
    my $class = ref($_[0]) || $_[0];
    return $class->SUPER::command_name unless $class eq __PACKAGE__;
    return 'genome report';
}

sub command_name_brief {
    my $class = ref($_[0]) || $_[0];
    return $class->SUPER::command_name_brief unless $class eq __PACKAGE__;
    return 'report';
}

############################################

1;

#$HeadURL$
#$Id$
