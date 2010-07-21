package Genome::Model::Command::Input::List;

use strict;
use warnings;

use Genome;
      
use Regexp::Common;

class Genome::Model::Command::Input::List {
    is => 'UR::Object::Command::List',
    doc => 'List inputs to a model.',
    has => [
        subject_class_name => {
            default_value => 'Genome::Model::Input',
            is_constant => 1,
        },
        show => {
            default_value => 'model_id,model_name,name,value_id',
        },
    ],
};

############################################

1;

#$HeadURL$
#$Id$
