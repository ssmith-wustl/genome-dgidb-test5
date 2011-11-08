#!/usr/bin/env perl

use strict;
use warnings;

use above "Genome";
use Test::More tests => 4;
use File::Compare;
use File::Temp qw(tempfile);

use_ok('Genome::Model::Tools::Sv::SvAnnot');

my $test_input_dir  = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Sv-SvAnnot/';
my $sv_file    = $test_input_dir . 'sv.file';
my $expect_out = $test_input_dir . 'sv.annot';

my $tmp_dir = File::Temp::tempdir(
    'Genome-Model-Tools-Sv-SvAnnot-XXXXX', 
    DIR     => '/gsc/var/cache/testsuite/running_testsuites', 
    CLEANUP => 1,
);
my $out_file = $tmp_dir .'/sv.annot';

my $annot_valid = Genome::Model::Tools::Sv::SvAnnot->create(
    sv_file => $sv_file,
    output_file   => $out_file,
    repeat_mask   => 1, 
    annot_build   => 36,
);

ok($annot_valid, 'created SvAnnot object');
ok($annot_valid->execute(), 'executed SvAnnot object OK');
is(compare($out_file, $expect_out), 0, 'output matched expected result');


