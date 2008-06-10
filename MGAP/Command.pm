
package MGAP::Command;

use strict;
use warnings;
use MGAP;
use Command;

class MGAP::Command {
    is => ['Command'],
    english_name => 'mgap command',
};

sub command_name {
    my $self = shift;
    my $class = ref($self) || $self;
    return 'mgap' if $class eq __PACKAGE__;
    return $self->SUPER::command_name(@_);
}

sub help_brief {
    "modularized commands for testing Workflow"
}

1;
