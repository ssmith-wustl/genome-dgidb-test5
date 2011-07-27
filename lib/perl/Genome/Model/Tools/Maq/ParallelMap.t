#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';
use Genome::Model::Tools::Maq::ParallelMap;
use Test::More;

#if (`uname -a` =~ /x86_64/){
#    plan tests => 18;
#} else{
    plan skip_all => 'This test takes too long just to test a parallel implementation';
#}

my $expected_output = 3;

my $ref_seq = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Maq/ParallelMap/all_sequences.bfa';

my $solexa_fastq_file = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Maq/ParallelMap/s_2_sequence.txt';
my @solexa_fastq_files = ('/gsc/var/cache/testsuite/data/Genome-Model-Tools-Maq/ParallelMap/s_2_1_sequence.txt', '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Maq/ParallelMap/s_2_2_sequence.txt');
my $sanger_fastq_file = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Maq/ParallelMap/s_2_sequence.fastq';
my @sanger_fastq_files = ('/gsc/var/cache/testsuite/data/Genome-Model-Tools-Maq/ParallelMap/s_2_1_sequence.fastq', '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Maq/ParallelMap/s_2_2_sequence.fastq');

my $tmp_dir = File::Temp::tempdir('Genome-Model-Tools-Maq-ParallelMap-XXXXX',DIR => '/gsc/var/cache/testsuite/running_testsuites', CLEANUP => 1);

my %tests = (
    'solexa_fragment_sol2phred' => {
        bfa_file => $ref_seq,
        fastq_files => $solexa_fastq_file,
        quality_converter => 'sol2phred',
        use_version => '0.7.1',
    },
    'solexa_fragment_sol2sanger' => {
        bfa_file => $ref_seq,
        fastq_files => $solexa_fastq_file,
        quality_converter => 'sol2sanger',
        use_version => '0.7.1',
    },
    'sanger_fragment' => {
        bfa_file => $ref_seq,
        fastq_files => $sanger_fastq_file,
        use_version => '0.7.1',
    },
    'solexa_pe_sol2phred' => {
        bfa_file => $ref_seq,
        fastq_files => \@solexa_fastq_files,
        quality_converter => 'sol2phred',
        use_version => '0.7.1',
    },
    'solexa_pe_sol2sanger' => {
        bfa_file => $ref_seq,
        fastq_files => \@solexa_fastq_files,
        quality_converter => 'sol2sanger',
        use_version => '0.7.1',
    },
    'sanger_pe' => {
        bfa_file => $ref_seq,
        fastq_files => \@sanger_fastq_files,
        use_version => '0.7.1',
    },
);

for my $test (keys %tests) {
    my %params = %{$tests{$test}};
    my $output_directory = File::Temp::tempdir($test.'-XXXX',DIR => $tmp_dir, CLEANUP => 1);
    $params{output_directory} = $output_directory;
    $params{sequences} = 50;
    my $mapper = Genome::Model::Tools::Maq::ParallelMap->create(%params);
    isa_ok($mapper,'Genome::Model::Tools::Maq::ParallelMap');
    ok($mapper->execute,'execute command '. $mapper->command_name);
    my @output_files = glob($output_directory.'/*');
    ok( scalar(@output_files) eq $expected_output, "Number of output files expected = ". $expected_output );
}

exit;



