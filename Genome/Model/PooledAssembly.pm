package Genome::Model::PooledAssembly;

use strict;
use warnings;

use Genome;
use Data::Dumper;
require Genome::ProcessingProfile::PooledAssembly;

class Genome::Model::PooledAssembly {
    is => 'Genome::Model',
    has => [
	    map { $_ => { via => 'processing_profile' } } 
            Genome::ProcessingProfile::PooledAssembly->params_for_class,

    ],
};

1;

