package Genome::GeneExpression;

use strict;
use warnings;

use Genome;

class Genome::GeneExpression {
    type_name => 'genome gene expression',
    table_name => 'GENE_EXPRESSION',
    id_by => [
        expression_id => { is => 'Number' },
    ],
    has => [
        expression_intensity => { is => 'FLoat' },
        dye_type => { is => 'String' },
        probe_sequence => { is => 'CLOB' },
        probe_identifier  => { is => 'String' },
        tech_type => { is => 'String' },
        detection => { is => 'String' },
    ],
    has_many => [
        gene_expressions => { is => 'Genome::GeneGeneExpression', reverse_id_by => 'gene_expression' },
        genes => { is => 'Genome::Gene', via => 'gene_expressions', to => 'gene' },
    ],
 
    schema_name => 'files',
    data_source => 'Genome::DataSource::GeneExpressions',
};

1;

