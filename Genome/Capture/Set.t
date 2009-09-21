#!/gsc/bin/perl

use strict;
use warnings;

use Test::More tests => 6;

use above 'Genome';

use_ok('Genome::Capture::Set');
my $capture_set = Genome::Capture::Set->get(id => '2151941');
isa_ok($capture_set,'Genome::Capture::Set');
is($capture_set->name,'RT45860 combined pool 55k (a/b) and 27k (1/2)','found correct capture set name');
is($capture_set->description,'RT45860 pool combining 4k001F, 4k001G, 4k001H, and 4k001K','found correct capture set description');
is($capture_set->status,'active','found correct capture set status');
my @set_targets = $capture_set->capture_set_targets;
ok(@set_targets,'got the capture set targets');
exit;
