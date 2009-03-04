package Genome::Submitter;

use strict;
use warnings;

use Genome;

class Genome::Submitter {
    type_name => 'genome submitter',
    table_name => 'SUBMITTER',
    id_by => [
        submitter_id => { is => 'Number' },
    ],
    has => [
        submitter_name => { is => 'String' },
        variation_source => { is => 'String' },
    ],
    has_many => [
        variation_instances => { is => 'Genome::VariationInstance', reverse_id_by => 'submitter' },
        variations => { is => 'Genome::Gene', via => 'variation_instances', to => 'variation' },
    ],
 
    schema_name => 'files',
    data_source => 'Genome::DataSource::Submitters',
};

1;

