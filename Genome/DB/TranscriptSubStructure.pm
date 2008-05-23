package Genome::DB::TranscriptSubStructure;

use strict;
use warnings;

use base 'DBIx::Class';

use Finfo::Logging 'fatal_msg';

__PACKAGE__->load_components(qw/ Core /);
__PACKAGE__->table('transcript_sub_structure');
__PACKAGE__->add_columns(qw/ 
    transcript_structure_id
    transcript_id
    structure_type
    structure_start
    structure_stop
    ordinal
    phase
    nucleotide_seq
    /);
__PACKAGE__->set_primary_key('transcript_structure_id');
__PACKAGE__->belongs_to('transcript', 'Genome::DB::Transcript', 'transcript_id');

1;

#$HeadURL$
#$Id$
