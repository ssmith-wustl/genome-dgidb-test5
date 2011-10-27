package Genome::GeneName;

use strict;
use warnings;

use Genome;

class Genome::GeneName {
    is => 'UR::Object',
    id_generator => '-uuid',
    table_name => 'gene_name',
    schema_name => 'subject',
    data_source => 'Genome::DataSource::Main',
    id_by => [
        id => {is => 'Text'},
    ],
    has => [
        name => { is => 'Text'},
        gene_name_reports => {
            calculate_from => 'name',
            calculate => q|
                return Genome::GeneNameReport->get(name => $name);
            |,
        },
    ],
    doc => 'Aggregation of Genome::GeneNameReports with the same gene name',
};

1;
