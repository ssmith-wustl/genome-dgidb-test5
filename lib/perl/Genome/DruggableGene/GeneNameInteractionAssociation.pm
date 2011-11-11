package Genome::DruggableGene::GeneNameInteractionAssociation;

use strict;
use warnings;

use Genome;

class Genome::DruggableGene::GeneNameInteractionAssociation {
    is => 'UR::Object',
    id_generator => '-uuid',
    table_name => 'dgidb.gene_name_interaction_association',
    schema_name => 'dgidb',
    data_source => 'Genome::DataSource::Main',
    id_by => [
        gene_name => { is => 'Text' },
        interaction_id => { is => 'Text' },
    ],
    has => [
        #TODO: throw in the interaction based on the interaction_id
    ],
    doc => '', #TODO: write me
};
