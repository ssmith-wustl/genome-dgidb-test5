#!/gsc/bin/perl

use strict;
use warnings;

use GSCApp;
use Data::Dumper;

use GSCApp::DF;
use GSCApp::Test tests => 6;

my $group = 'CORE';

my @disks = GSCApp::DF->get_disks_for_group($group);
ok(@disks, 'Getting disks for '.$group);

my $first = $disks[0];
is($first->{'group'}, $group, "Comparing group $group and ".$first->{'group'});

my $vol = $first->{'vol'};
ok($vol, 'Checking vol '.$vol);

my $path = '/gscmnt/'.$vol.'/';
my $path_exists;

    if (-e $path) {
        $path_exists++;
    }

ok($path_exists, 'Checking that path exists: '.$path);

my $disk_core_exists;
my $disk_core_file = $path.'DISK_CORE';

    if (-e  $disk_core_file) {
        $disk_core_exists++;
    }

ok($disk_core_exists, 'Checking for '.$disk_core_file);

$vol = 200;
@disks = GSCApp::DF->get_disks_for_vol($vol);
ok(@disks, 'Getting disks for vol '.$vol);




