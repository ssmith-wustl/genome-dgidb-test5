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

#copy test input files to temp dir
foreach my $file_name ('gap.txt', 'contigs.bases', 'readinfo.txt') {
    my $old = $data_dir.'/edit_dir/'.$file_name;
    my $new = $temp_dir.'/edit_dir/'.$file_name;
    ok (-e $old, "Test $file_name file exists"); #gap.txt can be blank
    ok(File::Copy::copy($old, $temp_dir.'/edit_dir'),"Copied $file_name to temp dir");
    ok (-e $new, "New $file_name exists");
}

my $ec = system("chdir $temp_dir; gmt assembly create-output-files reads-placed --directory $temp_dir");
ok($ec == 0, "Command ran successfully");

my $new_reads_placed_file = $temp_dir.'/edit_dir/reads.placed';
ok(-s $new_reads_placed_file, "New reads.placed file exists");

my $old_reads_placed_file = $data_dir.'/edit_dir/reads.placed';

my @diffs = `sdiff -s $new_reads_placed_file $old_reads_placed_file`;
is(scalar (@diffs), 0, "New file matches existing test file");

done_testing();

exit;
