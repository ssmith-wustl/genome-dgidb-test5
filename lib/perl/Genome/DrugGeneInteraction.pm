package Genome::DruggableGene::DrugGeneInteraction;

use strict;
use warnings;

use Genome;

=out
   interaction_type varchar NOT NULL,
   description text,
   nomenclature varchar NOT NULL,
   source_db_name varchar NOT NULL,
   source_db_version varchar NOT NULL,
   FOREIGN KEY(drug_name, nomenclature, source_db_name, source_db_version) REFERENCES drug_name(name, nomenclature, source_db_name, source_db_version),
   FOREIGN KEY(gene_name, nomenclature, source_db_name, source_db_version) REFERENCES gene_name(name, nomenclature, source_db_name, source_db_version),
   UNIQUE (drug_name, gene_name, interaction_type, nomenclature, source_db_name, source_db_version)
=cut
class Genome::DruggableGene::DrugGeneInteraction {
    table_name => 'drug_gene_interaction',
    schema_name => 'public',
    data_source => 'Genome::DataSource::Main',
    id_by => [
        id => { is => 'integer' },
    ],
    has => [
        drug_name => { is => 'varchar'},
        drug => {

        },
        gene => {

        },
        gene_name => { is => 'varchar'},
        nomenclature => { is => 'varchar'},
        source_db_name => { is => 'varchar'},
        source_db_version => { is => 'varchar'},
        interaction_type => { is => 'varchar'}, 
        description => { is => 'Text' },
        drug_gene_interaction_attributes => {
            calculate_from => ['id'],
            calculate => q|
                my @drug_gene_interaction_attributes = Genome::DruggableGene::DrugGeneInteractionAttribute->get(id => $id);
                return @drug_gene_interaction_attributes;
            |,
        },
    ],
};

1;
