#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More;
use File::Compare;

my $archos = `uname -a`;
if ($archos !~ /64/) {
    plan skip_all => "Must run from 64-bit machine";
} else {
    plan tests => 6;
}

my $test_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-DetectVariants2-Breakdancer';
my $test_working_dir = File::Temp::tempdir('DetectVariants2-Breakdancer-XXXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites/', CLEANUP => 1);

my $normal_bam = $test_dir . '/normal.bam';
my $tumor_bam  = $test_dir . '/tumor.bam';
my $cfg_file   = $test_dir . '/breakdancer_config';

my $chromosome = 22;
my $out_file   = $test_dir . '/svs.hq.'.$chromosome;
my $test_out   = $test_working_dir . '/svs.hq.'.$chromosome;

my $ref_seq_build = Genome::Model::Build::ImportedReferenceSequence->get(type_name => 'imported reference sequence', name => 'NCBI-human-build36');
ok($ref_seq_build, 'Got a reference sequence build') or die('Test cannot continue without a reference sequence build');
is($ref_seq_build->name, 'NCBI-human-build36', 'Got expected reference for test case');

my $ref_seq_input = $ref_seq_build->full_consensus_path('fa');
ok(Genome::Sys->check_for_path_existence($ref_seq_input), 'Got a reference FASTA') or die('Test cannot continue without a reference FASTA');

my $version = '2010_06_24';
note("use breakdancer version: $version");

my $command = Genome::Model::Tools::DetectVariants2::Breakdancer->create(
    reference_sequence_input => $ref_seq_input,
    aligned_reads_input => $tumor_bam,
    control_aligned_reads_input => $normal_bam,
    version => $version,
    sv_params  => '-g -h:-q 10 -o',
    chromosome => $chromosome,
    output_directory => $test_working_dir,
    config_file => $cfg_file,
);
ok($command, 'Created `gmt detect-variants2 breakdancer` command');
ok($command->execute, 'Executed `gmt detect-variants2 breakdancer` command');

is(compare($out_file, $test_out), 0, "svs.hq output as expected");

