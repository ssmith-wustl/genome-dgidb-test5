package Genome::GeneGeneExpression;

use strict;
use warnings;

use Genome;

class Genome::GeneGeneExpression {
    type_name => 'genome gene gene expression',
    table_name => 'GENE_GENE_EXPRESSION',
    id_by => [
        gene_id => { is => 'NUMBER' },
        expression_id => { is => 'NUMBER' },
    ],
    has => [
        gene => { is => 'Genome::Gene', id_by => 'gene_id' },
        expression => { is => 'Genome::GeneExpression', id_by => 'expression_id' },
    ],
    schema_name => 'files',
    data_source => 'Genome::DataSource::GeneGeneExpressions',
};

1;

