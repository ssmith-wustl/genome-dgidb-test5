#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
require File::Compare;
require File::Temp;
use Test::More;

use_ok('Genome::Model::Tools::Sx') or die;

my $dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Sx';
my $example_in_file = $dir.'/fast_qual.example.fastq';
ok(-s $example_in_file, 'example in fastq file exists');
my $example_out_file = $dir.'/fast_qual.example.fasta';
ok(-s $example_out_file, 'example out fasta file exists');
my $example_metrics_file = $dir.'/fast_qual.example.metrics';
ok(-s $example_metrics_file, 'example metrics file exists');
my $tmpdir = File::Temp::tempdir(CLEANUP => 1);

my $out_file = $tmpdir.'/out.fasta';
my $metrics_file = $tmpdir.'/metrics.txt';

my $fq = Genome::Model::Tools::Sx->create(
    input => [ $example_in_file ],
    output => [ $out_file ],
    metrics_file_out => $metrics_file,
);
ok($fq, 'create w/ fastq files');
ok($fq->execute, 'execute');
is(File::Compare::compare($out_file, $example_out_file), 0, 'output file ok');
is(File::Compare::compare($metrics_file, $example_metrics_file), 0, 'metrics file ok');

#print "$tmpdir\n"; <STDIN>;
done_testing();
exit;
    
