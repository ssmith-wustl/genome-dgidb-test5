package Genome::Model::Build::ImportedVariationList;


use strict;
use warnings;

use Data::Dumper;
use Genome;

class Genome::Model::Build::ImportedVariationList {
    is => 'Genome::Model::Build',
    has => [
        version => { 
            via => 'inputs',
            is => 'Text',
            to => 'value_id', 
            where => [ name => 'version', value_class_name => 'UR::Value'], 
            is_mutable => 1 
        },
        feature_list => {
            is => 'Genome::FeatureList',
            id_by => 'feature_list_id',
        },
        feature_list_id => {
            via => 'inputs',
            is => 'Text',
            to => 'value_id',
            where => [
                name => 'feature_list_id',
                value_class_name => 'Genome::FeatureList'
            ], 
            is_mutable => 1,
            doc => 'The feature list containing the imported variations',
        },
        reference => {
            is => 'Genome::Model::Build::ImportedReferenceSequence',
            via => 'feature_list',
            to => 'reference',
        },
    ],
};

1;
