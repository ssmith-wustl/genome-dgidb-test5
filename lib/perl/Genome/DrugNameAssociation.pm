package Genome::DrugNameAssociation;

use strict;
use warnings;

use Genome;

class Genome::DrugNameAssociation {
    is => 'UR::Object',
    id_generator => '-uuid',
    table_name => 'drug_name_association',
    schema_name => 'public',
    data_source => 'Genome::DataSource::Main',
    id_by => [
        id => {is => 'Text'},
    ],
    has => [
        drug_name_id => { is => 'Text'},
        #TODO: make this work
        # drug_name => {

        # },
        alternate_name => {is => 'Text'},
        nomenclature => { is => 'Text'},
        description => {
            is => 'Text',
            is_optional => 1,
        },
    ],
    doc => 'Claim regarding an alternate name for a drug name',
};

1;
