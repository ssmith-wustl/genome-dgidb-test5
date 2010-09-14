#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Test::More;

use_ok ('Genome::Model::Tools::Assembly::ReScaffoldMsiAce');

my $data_dir = '/gscmnt/sata420/info/testsuite_data/Genome-Model-Tools-Assembly/ReScaffoldMsiAce_v1';
ok(-d $data_dir, "Found data dir");

my $temp_dir = Genome::Utility::FileSystem->create_temp_directory();
ok(-d $temp_dir, "Made temp test dir");

mkdir $temp_dir.'/edit_dir';
ok(-d $temp_dir.'/edit_dir', "Made edit_dir in temp dir");

foreach ('test.ace', 'scaffolds') {
    ok(-s $data_dir."/edit_dir/$_", "Data dir $_ file exists");
    ok(File::Copy::copy($data_dir."/edit_dir/$_", $temp_dir."/edit_dir/"), "Copied $_ to temp_dir");
    ok(-s $temp_dir."/edit_dir/$_", "Temp dir $_ file exists");
}

my $create = Genome::Model::Tools::Assembly::ReScaffoldMsiAce->create (
    acefile => $temp_dir.'/edit_dir/test.ace',
    scaffold_file => $temp_dir.'/edit_dir/scaffolds',
    assembly_directory => $temp_dir,
    );
ok( $create, "Created re-scaffold-msi-ace");

ok( $create->execute, "Executed re-scaffold-msi-ace successfully");

ok(-s $temp_dir.'/edit_dir/ace.msi', "Created new scaffolded ace file");
my @diff = `sdiff -s $temp_dir/edit_dir/ace.msi $data_dir/edit_dir/ace.msi`;
is(scalar (@diff), 0, "New ace file matches test ace file");

ok(-s $temp_dir.'/edit_dir/msi.gap.txt', "Created msi.gap.txt file");
my @diff2 = `sdiff -s $temp_dir/edit_dir/msi.gap.txt $data_dir/edit_dir/msi.gap.txt`;
is(scalar (@diff2), 0, "New msi.gap.txt file matches test msi.gap.txt file");

#<STDIN>;

done_testing();

exit;
