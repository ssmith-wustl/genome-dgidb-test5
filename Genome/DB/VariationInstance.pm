package Genome::DB::VariationInstance;

use strict;
use warnings;

use base 'DBIx::Class';

use Finfo::Logging 'fatal_msg';

__PACKAGE__->load_components(qw/ Core /);
__PACKAGE__->table('variation_instance');
__PACKAGE__->add_columns
(qw/
    variation_id 
    submitter_id
    method_id
    date_stamp 
    /);
__PACKAGE__->set_primary_key(qw/ variation_id submitter_id /);
__PACKAGE__->belongs_to('variation', 'Genome::DB::Variation', 'variation_id');
__PACKAGE__->belongs_to('submitter', 'Genome::DB::Submitter', 'submitter_id');
    
1;

#$HeadURL$
#$Id$
