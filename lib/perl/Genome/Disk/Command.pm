package Genome::Disk::Command;

use strict;
use warnings;

use Genome;

class Genome::Disk::Command {
    is => 'Command',
    is_abstract => 1,
    doc => 'work with disk',
};

my @SUB_COMMANDS = qw/
    allocation
    volume
    group
    assignment
/;

our %SUB_COMMAND_CLASSES = 
    map {
        my @words = split(/-/,$_);
        my $class = join("::",
            'Genome',
            'Disk',
            join('',map{ ucfirst($_) } @words),
            'Command'
        );
        ($_ => $class);
    }
    @SUB_COMMANDS;

our @SUB_COMMAND_CLASSES = map { $SUB_COMMAND_CLASSES{$_} } @SUB_COMMANDS;

for my $class ( @SUB_COMMAND_CLASSES ) {
    eval("use $class;");
    die $@ if $@; 
}


############################################

sub command_name {
    my $class = ref($_[0]) || $_[0];
    return $class->SUPER::command_name unless $class eq __PACKAGE__;
    return 'genome disk';
}

sub command_name_brief {
    my $class = ref($_[0]) || $_[0];
    return $class->SUPER::command_name_brief unless $class eq __PACKAGE__;
    return 'disk';
}

############################################


#< Sub Command Stuff >#
sub is_sub_command_delegator {
    return 1;
}

sub sorted_sub_command_classes {
    return @SUB_COMMAND_CLASSES;
}

sub sub_command_classes {
    return @SUB_COMMAND_CLASSES;
}

sub class_for_sub_command {
    my $class = ref($_[0]) || $_[0];
    return $class->SUPER::class_for_sub_command unless $class eq __PACKAGE__;
    return $SUB_COMMAND_CLASSES{$_[1]};
}

1;

