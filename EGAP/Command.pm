package EGAP::Command;

use strict;
use warnings;

use EGAP;
use Command;

class EGAP::Command {
    is => ['Command'],
    english_name => 'egap command',
};

sub command_name {
    my $self = shift;
    my $class = ref($self) || $self;
    return 'egap' if $class eq __PACKAGE__;
    return $self->SUPER::command_name(@_);
}

sub help_brief {
    "modularized commands for testing Workflow"
}

1;
