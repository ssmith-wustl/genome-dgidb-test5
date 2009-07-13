package BAP::DB::GeneTag;

use base 'BAP::DB::DBI';
use DBD::Oracle qw(:ora_types);

__PACKAGE__->table('gene_tag');
__PACKAGE__->columns( All => qw(gene_id tag_id) );

# has a relationships?

1;

# $Id$
