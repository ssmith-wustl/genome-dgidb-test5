package Genome::Model::Build::Command::List;

use strict;
use warnings;

use Genome;

class Genome::Model::Build::Command::List {
    is => 'Genome::Model::Command::BuildRelatedList',
    has => [
        subject_class_name  => {
            is_constant => 1, 
            value => 'Genome::Model::Build' 
        },
        show => { default_value => 'id,model_id,model_name,date_scheduled,date_completed,data_directory' },
    ],
};

sub sub_command_sort_position { 1 }

1;

