# Review gsanders: This can be removed and has not been used for some time

package Genome::GeneGeneExpression;
#:adukes dump

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
        gene => {
            calculate_from => [qw/ gene_id build_id/],
            calculate => q|
                Genome::Gene->get(gene_id => $gene_id, build_id => $build_id);
            |,
        },
        expression => {
            calculate_from => [qw/ expression_id build_id/],
            calculate => q|
                Genome::GeneExpression->get(expression_id => $expression_id, build_id => $build_id);
            |,
        },
        build => {
            is => "Genome::Model::Build",
            id_by => 'build_id',
        },
    ],
    schema_name => 'files',
    data_source => 'Genome::DataSource::GeneGeneExpressions',
};

1;

