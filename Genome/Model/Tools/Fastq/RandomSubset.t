#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More tests => 7;
use File::Compare;

use_ok('Genome::Model::Tools::Fastq::RandomSubset');

my $tmp_dir = File::Temp::tempdir('Fastq-RandomSubset-XXXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites', CLEANUP => 1);

my $data_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Fastq/RandomSubset';
my $expected_50_file = $data_dir .'/50_seq.fastq';
my $expected_10_file = $data_dir .'/10_seq.fastq';
my $fastq_file = $data_dir .'/All.fastq';


my $rs_50 = Genome::Model::Tools::Fastq::RandomSubset->create(
        input_fastq_file => $fastq_file,
        output_fastq_file => $tmp_dir .'/tmp-50.fastq',
        #output_fastq_file => $expected_50_file,
        subset_size => 50,
        seed_phrase => 'test_seed',
        );
isa_ok($rs_50,'Genome::Model::Tools::Fastq::RandomSubset');
ok($rs_50->execute,'execute command '. $rs_50->command_name);
ok(!compare($rs_50->output_fastq_file,$expected_50_file),'expected 50 file equal');

my $rs_10 = Genome::Model::Tools::Fastq::RandomSubset->create(
        input_fastq_file => $fastq_file,
        output_fastq_file => $tmp_dir .'/tmp-10.fastq',
        #output_fastq_file => $expected_10_file,
        subset_size => 10,
        seed_phrase => 'test_seed',
        );
isa_ok($rs_10,'Genome::Model::Tools::Fastq::RandomSubset');
ok($rs_10->execute,'execute command '. $rs_10->command_name);
ok(!compare($rs_10->output_fastq_file,$expected_10_file),'expected 10 file equal');
exit;
