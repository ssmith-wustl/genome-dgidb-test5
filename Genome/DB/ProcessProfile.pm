package Genome::DB::ProcessProfile;

use strict;
use warnings;

use base 'DBIx::Class';

use Finfo::Logging 'fatal_msg';

__PACKAGE__->load_components(qw/ Core /);
__PACKAGE__->table('process_profile');
__PACKAGE__->add_columns(qw/ 
    pp_id
    detection_software
    source
    tech_type
    mapping_reference
    concatenated_string_id
    run_identifier
    /);
__PACKAGE__->set_primary_key('pp_id');
__PACKAGE__->has_many('read_groups', 'Genome::DB::ReadGroup', 'pp_id');

1;

#$HeadURL$
#$Id$
