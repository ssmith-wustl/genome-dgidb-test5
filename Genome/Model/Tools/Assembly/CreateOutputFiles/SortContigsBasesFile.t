#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Test::More;
require File::Compare;

my $module = 'Genome-Model-Tools-Assembly-CreateOutputFiles';
my $data_dir = "/gsc/var/cache/testsuite/data/$module";

ok(-d $data_dir, "Found data directory: $data_dir");

ok(-s $data_dir.'/edit_dir/unsorted.contigs.bases', "Unsorted bases file exists for testing");

ok(-s $data_dir.'/edit_dir/sorted.contigs.bases', "Sorted bases file exists for comparision"); 

my $temp_dir = Genome::Utility::FileSystem->create_temp_directory();

ok(File::Copy::copy($data_dir.'/edit_dir/unsorted.contigs.bases', $temp_dir), "Copied test unsorted contigs bases file");

my $test_file = $temp_dir.'/unsorted.contigs.bases';

ok(system("gmt assembly create-output-files sort-contigs-bases-file --file $test_file") == 0, "Command ran successfully");

my $sorted_file = $temp_dir.'/unsorted.contigs.bases'; #by default input file is sorted and renamed same input name

ok(-s $sorted_file, "Sorted contigs bases file created");

ok(File::Compare::compare($sorted_file, $data_dir.'/edit_dir/sorted.contigs.bases') == 0, "Sorted bases file match test sorted file");

done_testing();

exit;
