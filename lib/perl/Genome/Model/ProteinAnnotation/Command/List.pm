package Genome::Model::ProteinAnnotation::Command::List;

use strict;
use warnings;

use Genome;
use Command;
use Data::Dumper;

class Genome::Model::ProteinAnnotation::Command::List {
    is => 'UR::Object::Command::List',
    has => [
        subject_class_name  => {
            is_constant => 1,
            value => 'Genome::Model::ProteinAnnotation'
        },
        show => { default_value => 'id,name,subject,status,processing_profile.annotation_strategy,processing_profile' },
    ],
    doc => 'list protein annotation genome models',
};

1;

