package Genome::Model::PooledAssemblyDecomposition;

use strict;
use warnings;

use Genome;
use Data::Dumper;
require Genome::ProcessingProfile::PooledAssemblyDecomposition;

class Genome::Model::PooledAssemblyDecomposition {
    is => 'Genome::Model',
    has => [
	    map { $_ => { via => 'processing_profile' } } 
            Genome::ProcessingProfile::PooledAssemblyDecomposition->params_for_class,

    ],
};

1;

