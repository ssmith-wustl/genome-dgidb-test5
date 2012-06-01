#!/usr/bin/env perl

use strict;
use warnings;

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use above 'Genome';

use Test::More;
use Genome::SoftwareResult;
use File::Compare;

my $archos = `uname -a`;
if ($archos !~ /64/) {
    plan skip_all => "Must run from 64-bit machine";
} 

use_ok('Genome::Model::Tools::DetectVariants2::Samtools') or die;

my $refbuild_id = 101947881;
my $ref_seq_build = Genome::Model::Build::ImportedReferenceSequence->get($refbuild_id);
ok($ref_seq_build, 'human36 reference sequence build') or die;

no warnings;
# Override lock name because if people cancel tests locks don't get cleaned up.
*Genome::SoftwareResult::_resolve_lock_name = sub {
    return Genome::Sys->create_temp_file_path;
};
use warnings;

my $test_dir      = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-DetectVariants2-Samtools/';
my $test_base_dir = File::Temp::tempdir(
    'DetectVariants2-SamtoolsXXXXX', 
    DIR     => '/gsc/var/cache/testsuite/running_testsuites/', 
    CLEANUP => 1,
);
my @test_working_dirs = map{"$test_base_dir/output".$_}qw(1 2);

#Note this bam file contain 2 samples, which is different from single sample bam generated from our ref-align pipeline. 
#tmooney made this only for testing purpose. This causes snv output different between mpileup and pileup since samtools 
#mpileup recognizes two samples. Just use for now, the bam should be replaced by a single sample bam in the future
my $bam_input = $test_dir . '/alignments/102922275_merged_rmdup.bam';

# Updated to .v1 for addition of read depth field
# Updated to .v2 for changing the structure of the files in the output dir from 1) no more filtering snvs -- this was moved to the  filter module 2) output file names changed
# Updated to .v3 for correcting the output of insertions in the bed file
# Updated to .v4 for correcting the sort order of snvs.hq and indels.hq
# Updated to .v5 for adding 1 to the start and stop positions of insertions
# Updated to .v6 for TCGA-compliance vcf header
my $expected_dir = $test_dir . '/expected.v6/';
ok(-d $expected_dir, "expected results directory exists");

my @versions = qw(r613 r963);

my %params = (
    reference_build_id   => $refbuild_id,
    aligned_reads_input  => $bam_input,
    version              => $versions[0],
    params               => "",
    output_directory     => $test_working_dirs[0],
    aligned_reads_sample => 'TEST',
);

run_test('pileup', \%params);

#Now testing mpileup 
$params{version} = $versions[1];
$params{params}  = 'mpileup -uB';
$params{output_directory} = $test_working_dirs[1];

run_test('mpileup', \%params);

done_testing();
exit;


sub run_test {
    my ($type, $params) = @_;
    my $test_dir = $params->{output_directory};

    my $command = Genome::Model::Tools::DetectVariants2::Samtools->create(%$params);
    ok($command, 'Created `gmt detect-variants2 samtools` command with '. $type);
    $command->dump_status_messages(1);
    ok($command->execute, 'Executed `gmt detect-variants2 samtools` command with '. $type);

    my @expected_output_files = qw|
        indels.hq
        indels.hq.bed
        indels.hq.v1.bed
        indels.hq.v2.bed
        snvs.hq
        snvs.hq.bed
        snvs.hq.v1.bed
        snvs.hq.v2.bed 
    |;

    if ($type eq 'mpileup') {
        $expected_dir .= $type . '/';
        push @expected_output_files, qw(vars.vcf vars.vcf.sanitized);
    }
    elsif ($type eq 'pileup') {
        push @expected_output_files, qw(indels_all_sequences.filtered report_input_all_sequences);
    }
    else {
        die "$type is not valid\n";
    }

    for my $output_file (@expected_output_files){
        my $expected_file = $expected_dir."/".$output_file;
        my $actual_file   = $test_dir."/".$output_file;
        is(compare($actual_file, $expected_file), 0, "$output_file output matched expected output");
    }

    for my $file_name qw(snvs.vcf.gz indels.vcf.gz) {
        ok(-s $test_dir."/$file_name",   "Found $file_name");
        diff_vcf_gz($test_dir, $expected_dir, $file_name);
    }
    
    return 1;
}


sub diff_vcf_gz {
    my ($t_dir, $e_dir, $file_name) = @_;
    my ($test_vcf_gz, $expect_vcf_gz) = map{$_.'/'.$file_name}($t_dir, $e_dir);
    my $test_md5   = qx(zcat $test_vcf_gz | grep -vP '^##fileDate' | md5sum);
    my $expect_md5 = qx(zcat $expect_vcf_gz | grep -vP '^##fileDate' | md5sum);
    is ($test_md5, $expect_md5, "$file_name output matched expected output");
    return 1;
}

