package Genome::ModelGroup::Command;

use strict;
use warnings;

use Genome;

class Genome::ModelGroup::Command {
    is => ['Genome::Command::Base'],
    is_abstract => 1,
    has => [],
    doc => "work with model-groups",
};

sub command_name {
    my $class = ref($_[0]) || $_[0];
    return $class->SUPER::command_name unless $class eq __PACKAGE__;
    return 'genome model-group';
}

sub command_name_brief {
    my $class = ref($_[0]) || $_[0];
    return $class->SUPER::command_name_brief unless $class eq __PACKAGE__;
    return 'model-group';
}

sub help_synopsis {
    return <<"EOS"
genome model-group ...    
EOS
}

sub help_brief {
    return "work with model-groups";
}

sub help_detail {                           
    return <<EOS 
Top level command to hold commands for working with model-groups.
EOS
}

1;
