package Genome::Model::Build::ImportedVariations;

use strict;
use warnings;

use Genome;

class Genome::Model::Build::ImportedVariations {
    is => 'Genome::Model::Build',
    has => [
        version => { 
            via => 'attributes', 
            to => 'value', 
            where => [ property_name => 'version'], 
            is_mutable => 1 
        },
        variation_data_directory => {
            via => 'attributes',
            to => 'value',
            where => [ property_name => 'annotation_data_source_directory'],
            is_mutable => 1 
        },
    ],
};

1;
