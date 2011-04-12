#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Test::More tests => 7; 
use File::Compare;
use File::Temp;
use IO::File;

BEGIN {
    my $archos = `uname -a`;
    if ($archos !~ /64/) {
        plan skip_all => "Must run from 64-bit machine";
    } 
};

use_ok( 'Genome::Model::Tools::DetectVariants2::Filter::NovoRealign');

my $file_name = 'svs.hq';
my $test_input_dir  = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-DetectVariants2-Filter-NovoRealign/';
my $normal_bam  = $test_input_dir . 'chr16_17.normal.bam';
my $tumor_bam   = $test_input_dir . 'chr16_17.tumor.bam';
my $sv_file     = $test_input_dir . $file_name;

my $tmp_dir = File::Temp::tempdir(
    'Genome-Model-Tools-DetectVariants2-Filter-NovoRealign-XXXXX', 
    DIR     => '/gsc/var/cache/testsuite/running_testsuites', 
    CLEANUP => 1,
);

ok(-d $tmp_dir, "temp output directory made at $tmp_dir");

#my $ref_seq = Genome::Model::ImportedReferenceSequence->get(name => 'NCBI-human');
#my $build = $ref_seq->build_by_version('36');
#my $refbuild_id = 101947881;
my $refbuild_id = 109104543;   #human36_chr16_17_for_novo_test ref_seq_build I made for this test

my $sv_valid = Genome::Model::Tools::DetectVariants2::Filter::NovoRealign->create(
    input_directory     => $test_input_dir,
    detector_directory  => $test_input_dir,
    detector_version    => '2010_07_19',
    output_directory    => $tmp_dir,
    aligned_reads_input => $normal_bam,
    control_aligned_reads_input => $tumor_bam,
    reference_build_id  => $refbuild_id,
);

$sv_valid->dump_status_messages(1);

ok($sv_valid, 'created NovoRealign object');
ok($sv_valid->execute(), 'executed NovoRealign object OK');

my $tmp_out_file = $tmp_dir.'/svs.lq';
my $expect_file  = $test_input_dir.'/output_dir/svs.lq';
ok(-s $tmp_out_file, "output file svs.lq generated ok"); 
is(compare($tmp_out_file, $expect_file), 0, "output svs.lq matches as expected");

$tmp_out_file = $tmp_dir.'/svs.hq';
my $tmp_out_file_noheader = $tmp_out_file.'.noheader';

my $fh = IO::File->new($tmp_out_file) or die "Failed to open $tmp_out_file\n";
my $out_fh = IO::File->new(">$tmp_out_file_noheader") or die "Failed to open $tmp_out_file_noheader for writing\n";

while (my $line = $fh->getline) {
    next if $line =~ /^#/;
    $out_fh->print($line);
}

$fh->close;
$out_fh->close;

$expect_file = $test_input_dir.'/output_dir/svs.hq.noheader';
is(compare($tmp_out_file_noheader, $expect_file), 0, "output svs.hq matches as expected");

done_testing();

