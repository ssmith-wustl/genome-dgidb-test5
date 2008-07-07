package Genome::Model::Command::List::Models;

use strict;
use warnings;

use above "Genome";
use Command; 
use Data::Dumper;

class Genome::Model::Command::List::Models {
    is => 'UR::Object::Command::List',
    has => [
    subject_class_name  => {
         is_constant => 1, 
        value => 'Genome::Model' 
    }, 
    ],
};

1;

#$HeadURL$
#$Id$
