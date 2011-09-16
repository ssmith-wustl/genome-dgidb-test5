#!/usr/bin/env perl

use strict;
use warnings;

use above "Genome";
use Test::More;
use File::Compare;
use File::Temp qw(tempfile);
use File::Path qw(rmtree);

BEGIN {
    my $archos = `uname -a`;
    if ($archos !~ /64/) {
        plan skip_all => "Must run from 64-bit machine";
    } 
    else {
        plan tests => 9;
    }
};

use_ok( 'Genome::Model::Tools::Sv::AssemblyValidation');

my $test_input_dir  = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Sv-AssemblyValidation/';
my $normal_bam  = $test_input_dir . 'normal.bam';
my $sv_file     = $test_input_dir . 'sv.file';

my @file_names = qw(normal.out normal.cm_aln.out normal.bp_seq.out);
my @expected_files = map{$test_input_dir . $_}@file_names;

my $tmp_dir = File::Temp::tempdir(
    'Genome-Model-Tools-Sv-AssemblyValidation-XXXXX', 
    DIR     => '/gsc/var/cache/testsuite/running_testsuites', 
    CLEANUP => 1,
);

my @test_out_files = map{$tmp_dir.'/test.'.$_}@file_names;

my $sv_valid = Genome::Model::Tools::Sv::AssemblyValidation->create(
    sv_file   => $sv_file,
    bam_files => $normal_bam,
    output_file => $test_out_files[0],
    cm_aln_file => $test_out_files[1],
    breakpoint_seq_file => $test_out_files[2],
);

ok($sv_valid, 'created AssemblyValidation object');
ok($sv_valid->execute(), 'executed AssemblyValidation object OK');

for my $i (0..2) {
    ok(-s $test_out_files[$i], 'generated output file: '.$file_names[$i].' ok');
    is(compare($test_out_files[$i], $expected_files[$i]), 0, 'output matched expected results: '.$file_names[$i]);
}


