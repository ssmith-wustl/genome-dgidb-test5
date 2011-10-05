package Genome::GeneName;

use strict;
use warnings;

use Genome;

class Genome::GeneName {
    is => 'UR::Object',
    id_generator => '-uuid',
    table_name => 'gene_name',
    schema_name => 'public',
    data_source => 'Genome::DataSource::Main',
    id_by => [
        id => {is => 'Text'},
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
        gene_name_associations => {
            calculate_from => ['id'],
            calculate => q|
                my @gene_name_associations = Genome::GeneNameAssociation->get(gene_name_id => $id);
                return @gene_name_associations;
            |,
        },
        gene_name_category_associations => {
            calculate_from => ['id'],
            calculate => q|
                my @gene_name_category_associations = Genome::GeneNameCategoryAssociation->get(gene_name_id => $id);
                return @gene_name_category_associations;
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
