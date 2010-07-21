#!/gsc/bin/perl

use strict;
use warnings;

use Test::More tests => 7;

use above 'Genome';

use_ok('Genome::Capture::Oligo');
my $oligo = Genome::Capture::Oligo->get(572805);
isa_ok($oligo,'Genome::Capture::Oligo');
is($oligo->tag_id,'2753062191','Found tag id ');
is($oligo->target_id,'403382','Found target id');
isa_ok($oligo->target,'Genome::Capture::Target');
is($oligo->pse_id,'95402763','Found the pse id');
my @sets = $oligo->sets;
ok(@sets,'got the capture sets');
exit;
