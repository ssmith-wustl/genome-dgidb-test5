#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Test::More;

my $module = 'Genome-Model-Tools-Assembly-CreateOutputFiles';
my $data_dir = "/gsc/var/cache/testsuite/data/$module";

ok(-d $data_dir, "Found data directory: $data_dir");

my $temp_dir = Genome::Utility::FileSystem->create_temp_directory();

#make edit_dir in temp dir
mkdir $temp_dir.'/edit_dir';
ok(-d $temp_dir.'/edit_dir', "Made edit_dir in temp test_dir");

foreach my $file_name ('contigs.bases', 'gap.txt') {
    my $old = $data_dir.'/edit_dir/'.$file_name;
    my $new = $temp_dir.'/edit_dir/'.$file_name;
    ok (-s $old, "Test $file_name exists");
    ok(File::Copy::copy($old, $temp_dir.'/edit_dir'),"Copied $file_name to temp dir");
    ok (-s $new, "New $file_name exists in temp dir");
}

my $ec = system("chdir $temp_dir; gmt assembly create-output-files supercontigs-fasta --directory $temp_dir");
ok($ec == 0, "Command ran successfully");

my $test_file = $data_dir.'/edit_dir/supercontigs.fasta';
ok(-s $test_file, "Test supercontigs.fasta file exists");

my $temp_file = $temp_dir.'/edit_dir/supercontigs.fasta';
ok(-s $temp_file, "New temp supercontigs.fasta file created");

my @diffs = `sdiff -s $test_file $temp_file`;
is(scalar (@diffs), 0, "New file matches existing test file");

done_testing();

exit;

