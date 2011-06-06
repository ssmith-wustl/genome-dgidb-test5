package Genome::Model::Germline;

use strict;
use warnings;
use Genome;

class Genome::Model::Germline {
    is => 'Genome::Model',
    has => [
        source_model => {
            is => 'Genome::Model::ReferenceAlignment',
            id_by => 'source_model_id',
        },
        source_model_id => {
            is => 'Text',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'source_id', value_class_name => 'Genome::Model::ReferenceAlignment' ],
            is_many => 0,
            is_mutable => 1,
        },
    ],
};

1;

