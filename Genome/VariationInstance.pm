# Review gsanders: This can be removed and has not been used for some time

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
        build => {
                    is => "Genome::Model::Build",
                    id_by => 'build_id',
        },
        variation => {
            calculate_from => [qw/ variation_id build_id/],
            calculate => q|
                Genome::Variation->get(variation_id => $variation_id, build_id => $build_id);
            |,
 
        },
        submitter => {
            calculate_from => [qw/ submitter_id build_id/],
            calculate => q|
                Genome::Submitter->get(submitter_id => $submitter_id, build_id => $build_id);
            |,
        },
    ],
    schema_name => 'files',
    data_source => 'Genome::DataSource::VariationInstances',
};

1;
