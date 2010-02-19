package Genome::Model::Convergence;

use strict;
use warnings;

use Genome;

class Genome::Model::Convergence {
    is  => 'Genome::Model',
    has => [
        group => {
            is => 'Genome::ModelGroup',
            id_by => 'group_id',
            doc => 'The ModelGroup for which this is the Convergence model',
        },
        group_id => {
            is => 'Number',
            doc => 'The id for the ModelGroup for which this is the Convergence model'
        },
        members => {
            is => 'Genome::Model',
            via => 'group',
            is_many => 1,
            to => 'models',
            doc => 'Models that are members of this Convergence model.',
        },
    ],
    doc => <<EODOC
This model type attempts to use the data collected across many samples to generalize and summarize
knowledge about the group as a whole.
EODOC
};

1;
