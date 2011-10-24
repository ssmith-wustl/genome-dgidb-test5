package Genome::DrugName;

use strict;
use warnings;

use Genome;

class Genome::DrugName {
    is => 'UR::Object',
    id_generator => '-uuid',
    table_name => 'drug_name',
    schema_name => 'public',
    data_source => 'Genome::DataSource::Main',
    id_by => [
        id => { is => 'Text'},
    ],
    has => [
        name => { is => 'Text'},
        nomenclature => { is => 'Text'},
        source_db_name => { is => 'Text'},
        source_db_version => { is => 'Text'},
        description => {
            is => 'Text',
            is_optional => 1,
        },
        drug_name_associations => {
            is => 'Genome::DrugNameAssociation',
            reverse_as => 'drug_name',
            is_many => 1,
        },
        drug_name_category_associations => {
            is => 'Genome::DrugNameCategoryAssociation',
            reverse_as => 'drug_name',
            is_many => 1,
        },
        drug_gene_interactions => {
            is => 'Genome::DrugGeneInteraction',
            reverse_as => 'drug_name',
            is_many => 1,
        },
        gene_names => {
            is => 'Genome::DrugName',
            via => 'drug_gene_interactions',
            to => 'gene_name',
            is_many => 1,
        }
    ],
    doc => 'Claim regarding the name of a drug',
};

sub __display_name__ {
    my $self = shift;
    return $self->name . '(' . $self->source_db_name . ' ' . $self->source_db_version . ')';
}

1;
