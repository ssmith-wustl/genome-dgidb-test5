#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Test::More;
use File::Compare;

BEGIN {
    my $archos = `uname -a`;
    if ($archos !~ /64/) {
        plan skip_all => "Must run from 64-bit machine";
    } 
    else {
        plan tests => 5;
    }
};

use_ok( 'Genome::Model::Tools::Sv::CrossMatchForIndel');

my $test_input_dir  = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Sv-CrossMatchForIndel/';
my $cm_file  = $test_input_dir . 'cm.file';
my $ref_seq  = $test_input_dir . 'ref.seq';
my $ctg_file = $test_input_dir . 'contig.seq';
my $out_file = $test_input_dir . 'out.file';

my $tmp_dir = File::Temp::tempdir(
    'Genome-Model-Tools-Sv-CrossMatchForIndel-XXXXX', 
    DIR     => '/gsc/var/cache/testsuite/running_testsuites', 
    CLEANUP => 1,
);

my $test_out_file = $tmp_dir .'/test.out.file';

my $cm = Genome::Model::Tools::Sv::CrossMatchForIndel->create(
    output_file          => $test_out_file,
    cross_match_file     => $cm_file,
    local_ref_seq_file   => $ref_seq,
    assembly_contig_file => $ctg_file,
    per_sub_rate         => 0.02,
    ref_start_pos        => '16_8646775_16_8646775_INS_93_+-',
);

ok($cm, 'created CrossMatchForIndel object ok');
ok($cm->execute(), 'executed CrossMatchForIndel object OK');

ok(-s $test_out_file, 'generated output file ok');
is(compare($test_out_file, $out_file), 0, 'output file is generated as expected');

