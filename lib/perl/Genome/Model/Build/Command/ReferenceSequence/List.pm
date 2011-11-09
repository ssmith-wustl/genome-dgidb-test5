package Genome::Model::Build::Command::ReferenceSequence::List;

use strict;
use warnings;
use Genome;

class Genome::Model::Build::Command::ReferenceSequence::List {
    is => 'UR::Object::Command::List',
    has => [
        subject_class_name => {
            is_constant => 1,
            value => 'Genome::Model::Build::ImportedReferenceSequence',
        },
    ],
};

1;

