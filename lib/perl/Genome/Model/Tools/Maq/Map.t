#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';
use Genome::Model::Tools::Maq::Map;
use Test::More;

if (`uname -a` =~ /x86_64/){
    plan tests => 18;
} else{
    plan skip_all => 'Must run on a 64 bit machine';
}

my $expected_output = 3;

my $ref_seq = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Maq/Map/all_sequences.bfa';

my $solexa_fastq_file = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Maq/Map/s_2_sequence.txt';
my @solexa_fastq_files = ('/gsc/var/cache/testsuite/data/Genome-Model-Tools-Maq/Map/s_2_1_sequence.txt', '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Maq/Map/s_2_2_sequence.txt');
my $sanger_fastq_file = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Maq/Map/s_2_sequence.fastq';
my @sanger_fastq_files = ('/gsc/var/cache/testsuite/data/Genome-Model-Tools-Maq/Map/s_2_1_sequence.fastq', '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Maq/Map/s_2_2_sequence.fastq');

my $tmp_dir = File::Temp::tempdir('Genome-Model-Tools-Maq-Map-XXXXX',DIR => '/gsc/var/cache/testsuite/running_testsuites', CLEANUP => 1);

my %tests = (
    'solexa_fragment_sol2phred' => {
        bfa_file => $ref_seq,
        fastq_files => $solexa_fastq_file,
        quality_converter => 'sol2phred',
    },
    'solexa_fragment_sol2sanger' => {
        bfa_file => $ref_seq,
        fastq_files => $solexa_fastq_file,
        quality_converter => 'sol2sanger',
    },
    'sanger_fragment' => {
        bfa_file => $ref_seq,
        fastq_files => $sanger_fastq_file,
    },
    'solexa_pe_sol2phred' => {
        bfa_file => $ref_seq,
        fastq_files => \@solexa_fastq_files,
        quality_converter => 'sol2phred',
    },
    'solexa_pe_sol2sanger' => {
        bfa_file => $ref_seq,
        fastq_files => \@solexa_fastq_files,
        quality_converter => 'sol2sanger',
    },
    'sanger_pe' => {
        bfa_file => $ref_seq,
        fastq_files => \@sanger_fastq_files,
    },
);

for my $test (keys %tests) {
    my %params = %{$tests{$test}};
    my $output_directory = File::Temp::tempdir($test.'-XXXX',DIR => $tmp_dir, CLEANUP => 1);
    $params{output_directory} = $output_directory;
    my $mapper = Genome::Model::Tools::Maq::Map->create(%params);
    isa_ok($mapper,'Genome::Model::Tools::Maq::Map');
    ok($mapper->execute,'execute command '. $mapper->command_name);
    my @output_files = glob($output_directory.'/*');
    ok( scalar(@output_files) eq $expected_output, "Number of output files expected = ". $expected_output );
}

exit;



