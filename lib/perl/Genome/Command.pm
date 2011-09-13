package Genome::Command;

use strict;
use warnings;

use Genome;

use Data::Dumper;
require File::Basename;

class Genome::Command {
    is => 'Command::Tree',
};
         
my @SUB_COMMANDS = qw/
    disk
    feature-list
    individual
    instrument-data
    library
    model
    model-group
    population-group
    processing-profile
    project
    project-part
    report
    sample
    sys
    task
    taxon
    tools
/;

our %SUB_COMMAND_CLASSES = 
    map {
        my @words = split(/-/,$_);
        my $class = join("::",
            'Genome',
            join('',map{ ucfirst($_) } @words),
            'Command'
        );
        ($_ => $class);
    }
    @SUB_COMMANDS;

$SUB_COMMAND_CLASSES{'tools'} = 'Genome::Model::Tools';

our @SUB_COMMAND_CLASSES = map { $SUB_COMMAND_CLASSES{$_} } @SUB_COMMANDS;

for my $class ( @SUB_COMMAND_CLASSES ) {
    eval("use $class;");
    die $@ if $@; 
}

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
    my $self = shift;
    my $sub_command = shift;
    return $SUB_COMMAND_CLASSES{$sub_command};
}

1;
