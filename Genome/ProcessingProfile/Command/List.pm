package Genome::ProcessingProfile::Command::List;

#REVIEW fdu 11/20/1009
#Remove 'use Command' and 'use Data::Dumper'

use strict;
use warnings;

use Genome;
use Command; 
use Data::Dumper;

class Genome::ProcessingProfile::Command::List {
    is => 'UR::Object::Command::List',
    has => [
        subject_class_name  => {
            is_constant => 1, 
            value => 'Genome::ProcessingProfile' 
        },
        show => { default_value => 'id,type_name,name' },
    ],
};

1;

#$HeadURL$
#$Id$
