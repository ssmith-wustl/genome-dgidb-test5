#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Test::More;

use Genome::Model::Tools::Velvet::CreateContigsFiles;
require File::Compare;

#TODO - move to correct test suite module dir when all tests are configured
my $module = 'Genome-Model-Tools-Assembly-CreateOutputFiles2';
my $data_dir = "/gsc/var/cache/testsuite/data/$module";

ok(-d $data_dir, "Found data directory: $data_dir");

my $temp_dir = Genome::Utility::FileSystem->create_temp_directory();

#make edit_dir
mkdir $temp_dir.'/edit_dir';
ok(-d $temp_dir.'/edit_dir', "Made edit_dir in temp dir");

#link afg file in tmp dir
ok(-s $data_dir.'/velvet_asm.afg', "Data dir velvet_asm.afg file exists");
symlink($data_dir.'/velvet_asm.afg', $temp_dir.'/velvet_asm.afg');
ok (-s $temp_dir.'/velvet_asm.afg', "Linked afg file in tmp dir");

my $ec = system("chdir $temp_dir; gmt velvet create-contigs-files --afg-file $temp_dir/velvet_asm.afg --directory $temp_dir");
ok($ec == 0, "Command ran successfully");

foreach ('contigs.bases', 'contigs.quals') {
    my $test_file = $data_dir."/edit_dir/$_";
    ok(-s $test_file, "Test $_ file exists");
    my $temp_file = $temp_dir."/edit_dir/$_";
    ok(-s $temp_file, "Temp $_ file exists");
    ok(File::Compare::compare($test_file, $temp_file) == 0, "$_ files match");
}

done_testing();

exit;
