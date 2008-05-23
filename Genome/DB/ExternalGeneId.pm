package Genome::DB::ExternalGeneId;

use strict;
use warnings;

use base 'DBIx::Class';

use Finfo::Logging 'fatal_msg';

__PACKAGE__->load_components(qw/ Core /);
__PACKAGE__->table('external_gene_id');
__PACKAGE__->add_columns(qw/ egi_id gene_id id_type id_value /);
__PACKAGE__->set_primary_key('egi_id');
__PACKAGE__->belongs_to('gene', 'Genome::DB::Gene', 'gene_id');

1;

#$HeadURL$
#$Id$
