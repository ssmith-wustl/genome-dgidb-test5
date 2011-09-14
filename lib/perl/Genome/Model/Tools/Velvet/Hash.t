#!/usr/bin/env perl

use strict;
use warnings;

use above "Genome";
use File::Temp;
use Test::More;

if (Genome::Config->arch_os ne 'x86_64') {
    plan skip_all => 'requires 64-bit machine';
}
else {
    plan tests => 2;
}

use_ok('Genome::Model::Tools::Velvet::Hash');

my $test_dir  = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Velvet/Hash';
my $test_file = 'test1.fa';

my $tmp_dir   = File::Temp::tempdir(
    "VelvetHash_XXXXXX", 
    DIR     => '/gsc/var/cache/testsuite/running_testsuites',
    CLEANUP => 1,
);

my $vh = Genome::Model::Tools::Velvet::Hash->create(
    file_name => $test_dir.'/'.$test_file,
    directory => $tmp_dir,
);

ok($vh->execute, 'velveth runs ok');

exit;
