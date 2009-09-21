#!/gsc/bin/perl

use strict;
use warnings;

use Test::More tests => 6;

use above 'Genome';

use_ok('Genome::Capture::Target');
my $capture_target = Genome::Capture::Target->get(572805);
isa_ok($capture_target,'Genome::Capture::Target');
is($capture_target->sequence_tag_id,'2753062191','Found sequence tag id ');
is($capture_target->sequence_target_id,'403382','Found sequence target id');
is($capture_target->pse_id,'95402763','Found the pse id');
my @set_targets = $capture_target->capture_set_targets;
ok(@set_targets,'got the capture set targets');
exit;
