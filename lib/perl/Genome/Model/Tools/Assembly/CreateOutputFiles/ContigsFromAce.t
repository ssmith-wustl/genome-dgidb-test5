#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Test::More;

use Genome::Model::Tools::Assembly::CreateOutputFiles::ContigsFromAce;

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

my $ec = system("chdir $temp_dir; gmt assembly create-output-files contigs-from-ace --acefile $temp_dir/edit_dir/velvet_asm.ace --directory $temp_dir");
ok($ec == 0, "Command ran successfully");

foreach my $file ('contigs.bases', 'contigs.quals') {
    my $test_file = $data_dir.'/edit_dir/'.$file;
    my $new_file = $temp_dir.'/edit_dir/'.$file;
    ok (-s $test_file, "Test $file exists");
    ok (-s $new_file, "New $file exists");
    my @diffs = `sdiff -s $test_file $new_file`;
    is(scalar (@diffs), 0, "New $file file matches test $file file");
}

done_testing();

exit;

