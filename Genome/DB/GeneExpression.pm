package Genome::DB::GeneExpression;

use strict;
use warnings;

use base 'DBIx::Class';

use Finfo::Logging 'fatal_msg';

__PACKAGE__->load_components(qw/ Core /);
__PACKAGE__->table('gene_expression');
__PACKAGE__->add_columns(qw/ expression_id expression_intensity dye_type probe_sequence probe_identifier tech_type detection /);
__PACKAGE__->set_primary_key('expression_id');
__PACKAGE__->has_many('gene_expressions', 'Genome::DB::GeneGeneExpression', 'expression_id');
__PACKAGE__->many_to_many('genes', 'gene_expressions', 'gene');

1;

#$HeadURL$
#$Id$
