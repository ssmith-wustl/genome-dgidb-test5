#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Test::More;

require File::Compare;

#TODO - move to correct test suite module dir when all tests are configured
my $module = 'Genome-Model-Tools-Assembly-CreateOutputFiles2';
my $data_dir = "/gsc/var/cache/testsuite/data/$module";

ok(-d $data_dir, "Found data directory: $data_dir");

my $temp_dir = Genome::Utility::FileSystem->create_temp_directory();

#make edit_dir
mkdir $temp_dir.'/edit_dir';
ok(-d $temp_dir.'/edit_dir', "Made edit_dir in temp dir");

#link project dir files
foreach ('velvet_asm.afg', 'Sequences') {
    ok(-s $data_dir.'/'.$_, "Data dir $_ file exists"); 
    symlink ($data_dir.'/'.$_, $temp_dir.'/'.$_);
    ok(-s $temp_dir.'/'.$_, "Tmp dir $_ file exists");
}

#link edit_dir files

my $ec = system("chdir $temp_dir; gmt velvet create-unplaced-reads-files --sequences-file $temp_dir/Sequences --afg-file $temp_dir/velvet_asm.afg --directory $temp_dir");
ok($ec == 0, "Command ran successfully");

foreach ('reads.unplaced', 'reads.unplaced.fasta') {
    ok(-s $data_dir."/edit_dir/$_", "Data dir $_ file exists");
    ok(-s $temp_dir."/edit_dir/$_", "Tmp dir $_ file got created");
    ok(File::Compare::compare($data_dir."/edit_dir/$_", $temp_dir."/edit_dir/$_") == 0, "$_ files match");
}

done_testing();

exit;
