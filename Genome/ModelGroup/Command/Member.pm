package Genome::ModelGroup::Command::Member;

use strict;
use warnings;

use Genome;

class Genome::ModelGroup::Command::Member {
    is => ['Command'],
    has => [
        model_group => { is => 'Genome::ModelGroup', id_by => 'model_group_id' },
        model_group_id => { is => 'Integer', doc => 'id of the model-group to work with'},
    ],
    doc => "work with the members of model-groups",
};

sub help_synopsis {
    return <<"EOS"
genome model-group member ...   
EOS
}

sub help_brief {
    return "work with the members of model-groups";
}

sub help_detail {                           
    return <<EOS 
Top level command to hold commands for working with the list of models belonging to model-groups.
EOS
}

1;
