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
my $input_metrics_file = $tmpdir.'/metrics.in.txt';
my $output_metrics_file = $tmpdir.'/metrics.out.txt';

my $fq = Genome::Model::Tools::Sx->create(
    input => [ $example_in_file ],
    input_metrics => $input_metrics_file,
    output => [ $out_file ],
    output_metrics => $output_metrics_file,
);
ok($fq, 'create w/ fastq files');
ok($fq->execute, 'execute');
is(File::Compare::compare($input_metrics_file, $example_metrics_file), 0, 'input metrics file ok');
is(File::Compare::compare($out_file, $example_out_file), 0, 'output file ok');
is(File::Compare::compare($output_metrics_file, $example_metrics_file), 0, 'output metrics file ok');

#$fq = Genome::Model::Tools::Sx->create();
#ok($fq, 'create w/o inputs and outputs');

#print "$tmpdir\n"; <STDIN>;
done_testing();
exit;
    
