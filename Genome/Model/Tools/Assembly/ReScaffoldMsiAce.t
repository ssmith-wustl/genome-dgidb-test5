#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Test::More;

my $data_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Assembly-ReScaffoldMsiAce';
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

my $ec = system("chdir $temp_dir; gmt assembly re-scaffold-msi-ace --acefile $temp_dir/edit_dir/test.ace --scaffold-file $temp_dir/edit_dir/scaffolds --assembly-directory $temp_dir");
ok($ec == 0, "Executed command successfully");

ok(-s $temp_dir.'/edit_dir/ace.msi', "Created new scaffolded ace file");

#my $new_ace = $temp_dir.'/edit_dir/ace.msi';
#my $old_ace = $data_dir.'/edit_dir/ace.msi';

my @diff = `sdiff -s $temp_dir/edit_dir/ace.msi $data_dir/edit_dir/ace.msi`;

is(scalar (@diff), 0, "New ace file matches test ace file");

done_testing();

exit;
