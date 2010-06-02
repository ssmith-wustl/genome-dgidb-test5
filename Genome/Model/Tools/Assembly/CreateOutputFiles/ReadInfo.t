#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Test::More;

my $module = 'Genome-Model-Tools-Assembly-CreateOutputFiles';
my $data_dir = "/gsc/var/cache/testsuite/data/$module";

ok(-d $data_dir, "Found data directory: $data_dir");

my $test_ace = $data_dir.'/edit_dir/velvet_asm.ace';
ok(-s $test_ace, "Found test ace file");

my $temp_dir = Genome::Utility::FileSystem->create_temp_directory();

#make edit_dir in temp_dir
mkdir $temp_dir.'/edit_dir';
ok(-d $temp_dir.'/edit_dir', "Made edit_dir in temp test_dir");

ok(File::Copy::copy($test_ace, $temp_dir.'/edit_dir'),"Copied input ace file to temp dir");

my $ec = system("chdir $temp_dir; gmt assembly create-output-files read-info --directory $temp_dir");
ok($ec == 0, "Command ran successfully");

my $test_file = $data_dir.'/edit_dir/readinfo.txt';
ok (-s $test_file, "Test readinfo.txt file exists");

my $new_file = $temp_dir.'/edit_dir/readinfo.txt';
ok(-s $new_file, "New readinfo.txt file exists");

my @diffs = `sdiff -s $test_file $new_file`;
is(scalar (@diffs), 0, "New file matches existing test file");

done_testing();

exit;
