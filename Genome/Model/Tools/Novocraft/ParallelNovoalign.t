#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';
use Genome::Model::Tools::Novocraft::ParallelNovoalign;
use Test::More;

#plan skip_all => 'slooooow';

if (`uname -a` =~ /x86_64/){
    plan tests => 6;
} else{
    plan skip_all => 'Must run on a 64 bit machine';
}

my $CLEANUP = 1;
my $TESTING_LSF_RESOURCE = "-R 'select[type==LINUX64]'";
my $TESTING_LSF_QUEUE = 'short';
my $TESTING_THREADS = 1;

my $expected_output = 2;
my $test_data_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Novocraft/Novoalign';
my $ref_seq = Genome::Config::reference_sequence_directory() . '/human-novoalign-reference-test/all_sequences_k14_s3';

my $fragment_fastq_file = $test_data_dir .'/fragment_100.txt';
my $pe_fastq_files = $test_data_dir .'/s_1_1_sequence_100.txt '. $test_data_dir .'/s_1_2_sequence_100.txt';

my $tmp_dir = File::Temp::tempdir('Genome-Model-Tools-Novocraft-ParallelNovoalign-XXXXX',DIR => '/gsc/var/cache/testsuite/running_testsuites', CLEANUP => $CLEANUP);

my $fragment_output_directory = File::Temp::tempdir('Fragment-XXXX',DIR => $tmp_dir, CLEANUP => $CLEANUP);
my $mapper = Genome::Model::Tools::Novocraft::ParallelNovoalign->create(
    output_directory => $fragment_output_directory,
    novoindex_file => $ref_seq,
    fastq_files => $fragment_fastq_file,
    lsf_queue => $TESTING_LSF_QUEUE,
    lsf_resource => $TESTING_LSF_RESOURCE,
    sequences => 25,
    threads => $TESTING_THREADS,
);
isa_ok($mapper,'Genome::Model::Tools::Novocraft::ParallelNovoalign');
ok($mapper->execute,'execute command '. $mapper->command_name);
my @fragment_output_files = grep { -f } glob($fragment_output_directory.'/*');
ok( scalar(@fragment_output_files) eq $expected_output, "Number of output files expected = ". $expected_output );

#Run Paired-End test
my $pe_output_directory = File::Temp::tempdir('Paired-End-XXXX',DIR => $tmp_dir, CLEANUP => $CLEANUP);
my $pe_mapper = Genome::Model::Tools::Novocraft::ParallelNovoalign->create(
    output_directory => $pe_output_directory,
    novoindex_file => $ref_seq,
    fastq_files => $pe_fastq_files,
    lsf_queue => $TESTING_LSF_QUEUE,
    lsf_resource => $TESTING_LSF_RESOURCE,
    sequences => 25,
    threads => $TESTING_THREADS,
);
isa_ok($pe_mapper,'Genome::Model::Tools::Novocraft::ParallelNovoalign');
ok($pe_mapper->execute,'execute command '. $pe_mapper->command_name);
my @pe_output_files = grep { -f } glob($pe_output_directory.'/*');
ok( scalar(@pe_output_files) eq $expected_output, "Number of output files expected = ". $expected_output );
exit;



