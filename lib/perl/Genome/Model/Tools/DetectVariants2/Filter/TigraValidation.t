#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";
use Test::More tests => 18; 
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

ok($sv_valid, 'created TigraValidation object');
ok($sv_valid->execute(), 'executed TigraValidation object OK');

my @test_file_names = qw(svs.out svs.out.normal svs.out.tumor breakpoint_seq.normal.fa breakpoint_seq.tumor.fa cm_aln.out.normal cm_aln.out.tumor);
for my $file_name (@test_file_names) {
    ok(-s $tmp_dir."/$file_name", "output file $file_name generated ok"); 
    is(compare($tmp_dir."/$file_name", $test_input_dir."/$file_name"), 0, "output $file_name matches as expected");
}

done_testing();

