#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use File::Compare;

use above 'Genome';

BEGIN {

    if (`uname -a` =~ /x86_64/){
        plan tests => 4;
    } else{
        plan skip_all => 'Must run on a 64 bit machine';
    }
    use_ok('Genome::Model::Tools::Maq::FastaToBfa');
}

my $tmp_dir = File::Temp::tempdir('Genome-Model-Tools-Maq-FastaToBfa-XXXXX', DIR => '/gsc/var/cache/testsuite/running_testsuites', CLEANUP => 1);
my $file_name = 'all_sequences';
my $existing_data_dir = Genome::Config::reference_sequence_directory() . '/refseq-for-test';
my $fasta_file = $existing_data_dir .'/'. $file_name .'.fa';
my $existing_bfa_file = $existing_data_dir .'/'. $file_name .'.bfa';

my $bfa_file = $tmp_dir .'/'. $file_name .'.bfa';

my $command = Genome::Model::Tools::Maq::FastaToBfa->create(
                                                            fasta_file => $fasta_file,
                                                            bfa_file => $bfa_file,
                                                        );
isa_ok($command,'Genome::Model::Tools::Maq::FastaToBfa');

ok($command->execute,'execute command '. $command->command_name);
ok(!File::Compare::compare($existing_bfa_file,$bfa_file),'files are the same');

exit;
