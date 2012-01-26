package Genome::Model::PooledAssemblyDecomposition;

use strict;
use warnings;

use Genome;
use Data::Dumper;
require Genome::ProcessingProfile::PooledAssemblyDecomposition;

class Genome::Model::PooledAssemblyDecomposition {
    is => 'Genome::ModelDeprecated',
    has => [
    	    (map { $_ => { via => 'processing_profile' } } 
                Genome::ProcessingProfile::PooledAssemblyDecomposition->params_for_class),            
            pooled_assembly_links => { 
                is => 'Genome::Model::Link', 
                reverse_as => 'to_model', 
                where => [ role => 'pooled_assembly'], 
                is_many => 1,
                doc => '' 
           },
           pooled_assembly => { 
                is => 'Genome::Model', 
                via => 'pooled_assembly_links', 
                to => 'from_model',
                doc => '' 
           },
    ],   
    
};

1;
