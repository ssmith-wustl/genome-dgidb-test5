# Review gsanders: This can be removed and has not been used for some time

package Genome::GeneExpression;
#:adukes dump

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
        build => {
                    is => "Genome::Model::Build",
                    id_by => 'build_id',
        },
    ],
    has_many => [
        gene_expressions => {
             calculate_from => [qw/ expression_id build_id/],
             calculate => q|
                Genome::GeneGeneExpression->get(expression_id => $expression_id, build_id => $build_id);
            |,
        },
        genes => { is => 'Genome::Gene', via => 'gene_expressions', to => 'gene' },
    ],
 
    schema_name => 'files',
    data_source => 'Genome::DataSource::GeneExpressions',
};

1;

