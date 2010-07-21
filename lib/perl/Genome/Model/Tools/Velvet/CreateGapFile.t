#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Test::More;

use Genome::Model::Tools::Velvet::CreateGapFile;
              
my $module = 'Genome-Model-Tools-Assembly-CreateOutputFiles2';
my $data_dir = "/gsc/var/cache/testsuite/data/$module";

ok(-d $data_dir, "Found data directory: $data_dir");

#test gap.txt file
#ok(-s $data_dir.'/edit_dir/gap.txt', "Found test gap.txt file");

my $test_contigs_file = $data_dir.'/contigs.fa';
ok(-s $test_contigs_file, "Found test contigs.fa file");

my $temp_dir = Genome::Utility::FileSystem->create_temp_directory();
#copy input file
ok(File::Copy::copy($test_contigs_file, $temp_dir),"Copied input contigs file");

#make edit_dir in temp_dir
mkdir $temp_dir.'/edit_dir';
ok(-d $temp_dir.'/edit_dir', "made edit_dir in temp test_dir");

my $ec = system("chdir $temp_dir; gmt velvet create-gap-file --contigs-fasta-file $test_contigs_file --directory $temp_dir");
ok($ec == 0, "Command ran successfully");

#test gap.txt file .. this file can be blank
my $test_gap_file = $data_dir.'/edit_dir/gap.txt';
ok(-e $test_gap_file, "Test gap.txt file exists");

#new gap.txt file
my $new_gap_file = $temp_dir.'/edit_dir/gap.txt';
ok(-e $new_gap_file, "New gap.txt file exits");

#diff
my @diffs = `sdiff -s $test_gap_file $new_gap_file`;
is(scalar (@diffs), 0, "New gap file matches test gap file");

done_testing();

exit;
