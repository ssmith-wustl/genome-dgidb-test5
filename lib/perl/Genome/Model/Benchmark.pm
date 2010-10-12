package Genome::Model::Benchmark;

use strict;
use warnings;
use Genome;

class Genome::Model::Benchmark {
    is => 'Genome::Model',
    has => [
        command_arguments => {
            is => 'UR::Value',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'command_arguments', value_class_name => 'UR::Value' ],
            is_mutable => 1,
        }
    ],
};

1;

