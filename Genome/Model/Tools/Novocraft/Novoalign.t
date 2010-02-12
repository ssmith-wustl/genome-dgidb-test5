#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';
use Genome::Model::Tools::Novocraft::Novoalign;
use Test::More;

if (`uname -a` =~ /x86_64/){
    plan tests => 6;
} else{
    plan skip_all => 'Must run on a 64 bit machine';
}

my $expected_output = 2;

my $test_data_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Novocraft/Novoalign';
my $ref_seq = '/gscmnt/839/info/medseq/reference_sequences/human-novoalign-reference-test/all_sequences_k14_s3';

my $fragment_fastq_file = $test_data_dir .'/fragment_100.txt';
my $pe_fastq_files = $test_data_dir .'/s_1_1_sequence_100.txt '. $test_data_dir .'/s_1_2_sequence_100.txt';

my $tmp_dir = File::Temp::tempdir('Genome-Model-Tools-Novocraft-Novoalign-XXXXX',DIR => '/gsc/var/cache/testsuite/running_testsuites', CLEANUP => 1);

my $fragment_output_directory = File::Temp::tempdir('Fragment-XXXX',DIR => $tmp_dir, CLEANUP => 1);
my $mapper = Genome::Model::Tools::Novocraft::Novoalign->create(
    output_directory => $fragment_output_directory,
    novoindex_file => $ref_seq,
    fastq_files => $fragment_fastq_file,
    threads => 1,
);
isa_ok($mapper,'Genome::Model::Tools::Novocraft::Novoalign');
ok($mapper->execute,'execute command '. $mapper->command_name);
my @fragment_output_files = glob($fragment_output_directory.'/*');
ok( scalar(@fragment_output_files) eq $expected_output, "Number of output files expected = ". $expected_output );

#Run Paired-End test
my $pe_output_directory = File::Temp::tempdir('Paired-End-XXXX',DIR => $tmp_dir, CLEANUP => 1);
my $pe_mapper = Genome::Model::Tools::Novocraft::Novoalign->create(
    output_directory => $pe_output_directory,
    novoindex_file => $ref_seq,
    fastq_files => $pe_fastq_files,
    threads => 1,
);
isa_ok($pe_mapper,'Genome::Model::Tools::Novocraft::Novoalign');
ok($pe_mapper->execute,'execute command '. $pe_mapper->command_name);
my @pe_output_files = glob($pe_output_directory.'/*');
ok( scalar(@pe_output_files) eq $expected_output, "Number of output files expected = ". $expected_output );
exit;



