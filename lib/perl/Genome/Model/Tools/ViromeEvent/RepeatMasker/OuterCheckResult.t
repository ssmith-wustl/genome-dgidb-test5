#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';
use Test::More;

use_ok('Genome::Model::Tools::ViromeEvent::RepeatMasker::OuterCheckResult');

my $data_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-ViromeScreening/Titanium17/Titanium17_undecodable';
ok( -d $data_dir, "Test suite data dir exists" );

my $temp_dir = Genome::Sys->create_temp_directory();

#create
my $c = Genome::Model::Tools::ViromeEvent::RepeatMasker::OuterCheckResult->create(
    dir     => $data_dir,
    logfile => $temp_dir.'/log.txt',
    );
ok($c, "Created repeat masker outer check result event");

done_testing();

exit;
