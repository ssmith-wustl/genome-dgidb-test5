package Genome::InstrumentData::Command::List;

use strict;
use warnings;

use Genome;
use Command; 
use Data::Dumper;

class Genome::InstrumentData::Command::List {
    is => 'UR::Object::Command::List',
    has => [
    subject_class_name  => {
        is_constant => 1, 
        value => 'Genome::InstrumentData' 
    },
    #show => { default_value => 'id,name,subject_name,processing_profile_name' },
    ],
};

1;

#$HeadURL$
#$Id$
