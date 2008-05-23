package Genome::DB::Submitter;

use strict;
use warnings;

use base 'DBIx::Class';

use Finfo::Logging 'fatal_msg';

__PACKAGE__->load_components(qw/ Core /);
__PACKAGE__->table('submitter');
__PACKAGE__->add_columns
(qw/
    submitter_id 
    submitter_name
    variation_source
    /);
__PACKAGE__->set_primary_key('submitter_id');
__PACKAGE__->has_one('instance', 'Genome::DB::VariationInstance', 'submitter_id');
__PACKAGE__->has_many('variation_instances', 'Genome::DB::VariationInstance', 'submitter_id');
__PACKAGE__->many_to_many('variations', 'variation_instances', 'variation');
    
1;

#$HeadURL$
#$Id$
