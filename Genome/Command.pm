package Genome::Command;

use strict;
use warnings;

use Genome;

use Data::Dumper;
require File::Basename;

class Genome::Command {
    is => 'Command',
    english_name => 'genome command',
};

our @SUB_COMMAND_DATA = (
    #'project'               => 'Genome::Project::Command',
    #'sample'                => 'Genome::Sample::Command',
    #'population-group'      => 'Genome::PopulationGroup::Command',
    'instrument-data'       => 'Genome::InstrumentData::Command',
    'processing-profile'    => 'Genome::ProcessingProfile::Command',
    'model'                 => 'Genome::Model::Command',
    'tools'                 => 'Genome::Model::Tools',
);
our %SUB_COMMAND_CLASSES = @SUB_COMMAND_DATA;

for my $class ( values %SUB_COMMAND_CLASSES ) {
    eval("use $class;");
    die $@ if $@; 
}

#< Command Naming >#
sub command_name {
    my $class = ref($_[0]) || $_[0];
    return $class->SUPER::command_name unless $class eq __PACKAGE__;
    return 'genome';
}

sub command_name_brief {
    my $class = ref($_[0]) || $_[0];
    return $class->SUPER::command_name_brief unless $class eq __PACKAGE__;
    return 'genome';
}

#< Sub Command Stuff >#
sub is_sub_command_delegator {
    return 1;
}

sub sub_command_classes {
    return values %SUB_COMMAND_CLASSES;
}

sub class_for_sub_command {
    my $class = ref($_[0]) || $_[0];
    return $class->SUPER::class_for_sub_command unless $class eq __PACKAGE__;
    return $SUB_COMMAND_CLASSES{$_[1]};
}

1;

#$HeadURL$
#$Id$

