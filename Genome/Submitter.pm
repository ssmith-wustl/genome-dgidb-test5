# Review gsanders: This can be removed and has not been used for some time

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
        build => {
                    is => "Genome::Model::Build",
                    id_by => 'build_id',
        },
    ],
    has_many => [
        variation_instances => {
            calculate_from => [qw/ submitter_id build_id/],
            calculate => q|
                Genome::VariationInstance->get(submitter_id => $submitter_id, build_id => $build_id);
            |,
        },
        variations => { is => 'Genome::Gene', via => 'variation_instances', to => 'variation' },
    ],
 
    schema_name => 'files',
    data_source => 'Genome::DataSource::Submitters',
};

1;

