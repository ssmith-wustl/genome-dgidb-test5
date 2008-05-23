package Genome::DB::Protein;

use strict;
use warnings;

use base 'DBIx::Class';

use Finfo::Logging 'fatal_msg';

__PACKAGE__->load_components(qw/ Core /);
__PACKAGE__->table('protein');
__PACKAGE__->add_columns(qw/ protein_id protein_name transcript_id amino_acid_seq /);
__PACKAGE__->set_primary_key('protein_id');
__PACKAGE__->belongs_to('transcript', 'Genome::DB::Transcript', 'transcript_id');
#__PACKAGE__->has_many(variations => 'Genome::DB::ProteinVariation');
#__PACKAGE__->has_many(features => 'Genome::DB::ProteinFeature');

1;

#$HeadURL$
#$Id$
