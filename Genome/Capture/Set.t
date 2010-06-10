#!/gsc/bin/perl

use strict;
use warnings;

use File::Compare;
use Test::More tests => 10;

use above 'Genome';

use_ok('Genome::Capture::Set');
my $capture_set = Genome::Capture::Set->get(id => '2151941');
isa_ok($capture_set,'Genome::Capture::Set');
is($capture_set->name,'RT45860 combined pool 55k (a/b) and 27k (1/2)','found correct capture set name');
is($capture_set->description,'RT45860 pool combining 4k001F, 4k001G, 4k001H, and 4k001K','found correct capture set description');
is($capture_set->status,'active','found correct capture set status');
my @set_oligos = $capture_set->set_oligos;
ok(@set_oligos,'got the capture set oligos');

my $tmp_file = Genome::Utility::FileSystem->create_temp_file_path('NimbleGen_Exome_Capture_v1.bed');
#my $tmp_file = 'NimbleGen_Exome_Capture_v1.bed';

my $expected_file = '/gsc/var/cache/testsuite/data/Genome-Capture-Set/NimbleGen_Exome_Capture_v1_zero-based.bed';

my $exome_capture_set = Genome::Capture::Set->get(name => 'nimblegen exome version 1');
isa_ok($exome_capture_set,'Genome::Capture::Set');
ok($exome_capture_set->print_bed_file($tmp_file),'dump the bed file to '. $tmp_file);
ok(!compare($tmp_file,$expected_file),'dumped bed file is identical to expected');
is($exome_capture_set->barcode,'4k002a','got the correct barcode');

exit;
