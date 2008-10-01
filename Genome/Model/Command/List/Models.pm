package Genome::Model::Command::List::Models;

use strict;
use warnings;

use Genome;
use Command; 
use Data::Dumper;

class Genome::Model::Command::List::Models {
    is => 'UR::Object::Command::List',
    has => [
        subject_class_name  => {
             is_constant => 1, 
            value => 'Genome::Model' 
        },
        show => { default_value => 'id,name,subject_name,processing_profile_name' },
    ],
};

sub sub_command_sort_position { 7 } 

1;

#$HeadURL$
#$Id$
