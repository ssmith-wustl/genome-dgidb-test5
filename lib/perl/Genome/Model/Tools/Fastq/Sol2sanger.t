#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 4;
use File::Compare;

use above 'Genome';

BEGIN {
    use_ok('Genome::Model::Tools::Fastq::Sol2sanger');
};

my $tmp_dir = File::Temp::tempdir('Fastq-SolToSanger-XXXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites', CLEANUP => 1);
my $fastq_file = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Fastq/SolToSanger/test.fq';
my $expected_sanger_fastq_file = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Fastq/SolToSanger/test.fq.sanger';

my $sol2sanger = Genome::Model::Tools::Fastq::Sol2sanger->create(
                                                                fastq_file => $fastq_file,
                                                                sanger_fastq_file => $tmp_dir .'/test.fastq',
                                                            );
isa_ok($sol2sanger,'Genome::Model::Tools::Fastq::Sol2sanger');

ok($sol2sanger->execute,'execute command '. $sol2sanger->command_name);
$DB::single = 1;
ok(compare($sol2sanger->sanger_fastq_file,$expected_sanger_fastq_file) == 0,'files are the same');

exit;
