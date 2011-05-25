#!/usr/bin/env perl

use strict;
use warnings;

use above "Genome";

use Test::More;
require File::Compare;

#check testdata dir
my $test_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Assembly-AutoJoin';
ok ( -d $test_dir, "Test data dir exists");

#create temp test dir and link files/dirs
my $temp_dir = Genome::Sys->create_temp_directory();
ok( -d $temp_dir, "Created test directory");

#phd_dir and files
ok (-d $test_dir.'/phd_dir', "Test dir phd dir exists");
symlink ($test_dir.'/phd_dir', $temp_dir.'/phd_dir');
ok (-l $temp_dir.'/phd_dir', "Linked phd_dir in temp test dir");

#phdball_dir
Genome::Sys->create_directory( $temp_dir.'/phdball_dir' );
ok (-d $temp_dir.'/phdball_dir', "Created temp sff_dir");
ok( -s $test_dir."/phdball_dir/autoJoinTestPhdBall", "Test dir phdball file exists");
symlink ($test_dir."/phdball_dir/autoJoinTestPhdBall", $temp_dir."/phdball_dir/autoJoinTestPhdBall");
ok( -l $temp_dir."/phdball_dir/autoJoinTestPhdBall", "Test phdball file linked in temp dir");

#sff stuff
Genome::Sys->create_directory( $temp_dir.'/sff_dir' );
ok (-d $temp_dir.'/sff_dir', "Created temp sff_dir");
foreach (qw/ ET1VHO301.sff ET1VHO302.sff EZ56J5101.sff /) {
    ok (-s $test_dir."/sff_dir/$_", "Temp $_ sff file exists");
    symlink ($test_dir."/sff_dir/$_", $temp_dir."/sff_dir/$_");
    ok (-l $temp_dir."/sff_dir/$_", "$_ sff file has been linked in temp dir");
}

#edit_dir
Genome::Sys->create_directory( $temp_dir.'/edit_dir' );
ok (-d $temp_dir.'/edit_dir', "Created temp edit_dir");
symlink ($test_dir.'/edit_dir/autojoin_test.ace', $temp_dir.'/edit_dir/autojoin_test.ace');
ok (-l $temp_dir.'/edit_dir/autojoin_test.ace', "Linked test ace file");

#create execute tool                                   
my $create = Genome::Model::Tools::Assembly::AutoJoin::ByFwdRevPairing->create(
    ace => 'autojoin_test.ace',
    dir => $temp_dir.'/edit_dir',
    );
ok( $create->execute, "Executed autojoin by scaffolding successfully");

#TODO compare output files .. will do today 10/29/10

done_testing();

exit;
