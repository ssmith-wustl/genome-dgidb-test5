package Genome::Model::Command::List;

use strict;
use warnings;

use Genome;
use Command; 
use Data::Dumper;

class Genome::Model::Command::List {
    is => 'UR::Object::Command::List',
    has => [
        subject_class_name  => {
            is_constant => 1, 
            value => 'Genome::Model' 
        },
        show => { default_value => 'id,name,subject_name,processing_profile_name' }
    ],
};

sub sub_command_sort_position { 3 }

sub help_brief {
    return 'List models';
}

# TODO: provide customized, detailed help
# sub help_detail {
#     return help_brief();
#}

sub is_subcommand_delegator { 1 }

1;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/Command/List.pm $
#$Id: List.pm 40876 2008-11-11 22:48:58Z ebelter $
