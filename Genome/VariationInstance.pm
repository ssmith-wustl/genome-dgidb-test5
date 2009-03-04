package Genome::VariationInstance;

use strict;
use warnings;
use Genome;

class Genome::VariationInstance {
    type_name => 'genome variation instance',
    table_name => 'VARIATION_INSTANCE',
    id_by => [
        variation_id => { is => 'NUMBER' },
        submitter_id => { is => 'NUMBER' },
    ],
    has => [
        method_id => { is => 'Number' },
        date_stamp => { is => 'String'},
        variation => {is => 'Genome::Variation', id_by => 'variation_id'},
        submitter => {is => 'Genome::Submitter', id_by => 'submitter_id'},
    ],
    schema_name => 'files',
    data_source => 'Genome::DataSource::VariationInstances',
};

1;
