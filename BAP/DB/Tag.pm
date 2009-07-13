package BAP::DB::Tag;

use base 'BAP::DB::DBI';
use DBD::Oracle qw(:ora_types);

__PACKAGE__->table('tag');
__PACKAGE__->columns( All => qw/tag_id tag_name tag_value/ );

__PACKAGE__->has_a('tag_name' => BAP::DB::TagNames);
__PACKAGE__->has_a('tag_value' => BAP::DB::TagValues);

1;
