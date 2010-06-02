#!/gsc/bin/perl

use strict;
use warnings;

use Cwd;
use above "Genome";
use Test::More;
require File::Compare;

my $module = 'Genome-Model-Tools-Assembly-CreateOutputFiles';
my $data_dir = "/gsc/var/cache/testsuite/data/$module";

ok(-d $data_dir, "Found data directory: $data_dir");

#create temp test dir
my $temp_dir = Genome::Utility::FileSystem->create_temp_directory();

#make edit_dir in temp_dir
my $edit_dir = $temp_dir.'/edit_dir';
mkdir $edit_dir;
ok(-d $edit_dir, "made edit_dir in temp test_dir");

#link files needed to run stats
my @files_to_link = qw/ velvet_asm.ace test.fasta.gz test.fasta.qual.gz
                        contigs.bases contigs.quals reads.placed /;
foreach my $file (@files_to_link) {
    ok(-s $data_dir."/edit_dir/$file", "Test data file $file file exists");
    symlink($data_dir."/edit_dir/$file", $edit_dir."/$file");
    ok(-s $temp_dir."/edit_dir/$file", "Linked $file $file in tmp test dir"); 
}

#create stats
ok(system ("gmt assembly stats velvet --assembly-directory $edit_dir --out-file stats.txt --no-print-to-screen") == 0, "Command ran successfully");

#check for stats files
ok(-s $temp_dir.'/edit_dir/stats.txt', "Tmp test dir stats.txt file exists");
ok(-s $edit_dir.'/stats.txt', "Test data dir stats.txt file exists");

#verify stats files are identical
ok(File::Compare::compare($temp_dir.'/edit_dir/stats.txt', $edit_dir.'/stats.txt') == 0, "Tmp dir and test data dir stats files match");

done_testing();

exit;
 

