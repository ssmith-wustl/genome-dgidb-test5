package Genome::Model::Command::List::Events;

use strict;
use warnings;

use above "Genome";

use Command; 
use Data::Dumper;

class Genome::Model::Command::List::Events {
    is => 'UR::Object::Command::List',
    has => [
    subject_class_name  => {
         is_constant => 1, 
        value => 'Genome::Model::Event' 
    }, 
    ],
};

1;

#$HeadURL$
#$Id$
