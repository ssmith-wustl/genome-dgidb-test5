package Genome::DrugName;

use strict;
use warnings;

use Genome;

class Genome::DrugName {
    is => 'UR::Object',
    id_generator => '-uuid',
    table_name => 'drug_name',
    schema_name => 'subject',
    data_source => 'Genome::DataSource::Main',
    id_by => [
        id => { is => 'Text'},
    ],
    has => [
        name => { is => 'Text' },
        drug_name_reports => {
            calculate_from => 'name',
            calculate => q|
                return Genome::DrugNameReport->get(name => $name);
            |,
        },
    ],
    doc => 'Aggregation of Genome::DrugNameReports with the same drug name',
};

1;
