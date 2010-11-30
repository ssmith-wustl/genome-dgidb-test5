package Genome::ModelGroup::Command::Member;

use strict;
use warnings;

use Genome;

class Genome::ModelGroup::Command::Member {
    is => 'Genome::Command::Base',
    is_abstract => 1,
    has => [
        model_group => { 
            is => 'Genome::ModelGroup', 
            shell_args_position => 1,
            doc => 'Model group name or id.',
        },
    ],
    doc => "work with the members of model-groups",
};

sub help_synopsis {
    return <<"EOS"
    work with the members of model-groups   
EOS
}

sub help_brief {
    return "work with the members of model-groups";
}

1;

