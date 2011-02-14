#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Test::More;

require File::Compare;

use_ok( 'Genome::Model::Tools::Velvet::CreateContigsFiles' );

#TODO - move to correct test suite module dir when all tests are configured
my $module = 'Genome-Model-Tools-Assembly-CreateOutputFiles2';
my $data_dir = "/gsc/var/cache/testsuite/data/$module";

ok(-d $data_dir, "Found data directory: $data_dir");

my $temp_dir = Genome::Sys->create_temp_directory();

#link afg file in tmp dir
ok(-s $data_dir.'/velvet_asm.afg', "Data dir velvet_asm.afg file exists");
symlink($data_dir.'/velvet_asm.afg', $temp_dir.'/velvet_asm.afg');
ok (-s $temp_dir.'/velvet_asm.afg', "Linked afg file in tmp dir");

my $create = Genome::Model::Tools::Velvet::CreateContigsFiles->create(
    assembly_directory => $temp_dir,
    );
ok( $create, "Created tool");
ok( $create->execute, "Successfully executed tool");

foreach ('contigs.bases', 'contigs.quals') {
    my $test_file = $data_dir."/edit_dir/$_";
    ok(-s $test_file, "Test $_ file exists");
    my $temp_file = $temp_dir."/edit_dir/$_";
    ok(-s $temp_file, "Temp $_ file exists");
    ok(File::Compare::compare($test_file, $temp_file) == 0, "$_ files match");
}

done_testing();

exit;
