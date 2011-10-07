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
            calculate_from => ['id'],
            calculate => q|
                my @drug_name_associations = Genome::DrugNameAssociation->get(drug_name_id => $id);
                return @drug_name_associations;
            |,
        },
        drug_name_category_associations => {
            calculate_from => ['id'],
            calculate => q|
                my @drug_name_category_associations = Genome::DrugNameCategoryAssociation->get(drug_name_id => $id);
                return @drug_name_category_associations;
            |,
        },
    ],
    doc => 'Claim regarding the name of a drug',
};

sub __display_name__ {
    my $self = shift;
    return $self->name . '(' . $self->source_db_name . ' ' . $self->source_db_version . ')';
}

1;
