package Genome::DB::GeneGeneExpression;

use strict;
use warnings;

use base 'DBIx::Class';

use Finfo::Logging 'fatal_msg';

__PACKAGE__->load_components(qw/ Core /);
__PACKAGE__->table('gene_gene_expression');
__PACKAGE__->add_columns(qw/ gene_id expression_id /);
__PACKAGE__->set_primary_key('gene_id', 'expression_id');
__PACKAGE__->belongs_to('gene', 'Genome::DB::Gene', 'gene_id');
__PACKAGE__->belongs_to('expression', 'Genome::DB::GeneExpression', 'expression_id');

1;

#$HeadURL$
#$Id$
