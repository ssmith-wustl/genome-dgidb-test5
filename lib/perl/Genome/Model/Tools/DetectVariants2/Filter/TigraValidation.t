#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Test::More tests => 10; 
use File::Compare;
use File::Temp;

BEGIN {
    my $archos = `uname -a`;
    if ($archos !~ /64/) {
        plan skip_all => "Must run from 64-bit machine";
    } 
};

use_ok( 'Genome::Model::Tools::DetectVariants2::Filter::TigraValidation');

my $test_input_dir  = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-DetectVariants2-Filter-TigraValidation/';
my $normal_bam  = $test_input_dir . 'normal.bam';
my $tumor_bam   = $test_input_dir . 'tumor.bam';
my $sv_file     = $test_input_dir . 'svs.hq';

my @file_names = qw(normal.out normal.cm_aln.out normal.bp_seq.out);
my @expected_files = map{$test_input_dir . $_}@file_names;

my $tmp_dir = File::Temp::tempdir(
    'Genome-Model-Tools-DetectVariants2-Filter-TigraValidation-XXXXX', 
    DIR     => '/gsc/var/cache/testsuite/running_testsuites', 
    CLEANUP => 1,
);

ok(-d $tmp_dir, "temp output directory made at $tmp_dir");

my $ref_seq = Genome::Model::ImportedReferenceSequence->get(name => 'NCBI-human');
my $build = $ref_seq->build_by_version('36');

my $sv_valid = Genome::Model::Tools::DetectVariants2::Filter::TigraValidation->create(
    input_directory  => $test_input_dir,
    output_directory => $tmp_dir,
    aligned_reads_input => $normal_bam,
    control_aligned_reads_input => $tumor_bam,
    reference_sequence_input => $build->sequence_path,
    specify_chr => 18,
);

ok($sv_valid, 'created AssemblyValidation object');
ok($sv_valid->execute(), 'executed AssemblyValidation object OK');

for my $file_name (qw(tigra.out breakpoint_seq.fa cm_aln.out)) {
    ok(-s $tmp_dir."/$file_name", "output file $file_name generated ok"); 
    is(compare($tmp_dir."/$file_name", $test_input_dir."/$file_name"), 0, "output $file_name matches as expected");
}

done_testing();

