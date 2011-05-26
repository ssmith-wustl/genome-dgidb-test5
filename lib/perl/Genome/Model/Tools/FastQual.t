#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
require File::Compare;
require File::Temp;
use Test::More;

use_ok('Genome::Model::Tools::FastQual') or die;

# Files
my $dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-FastQual';
my $example_in_file = $dir.'/fast_qual.example.fastq';
ok(-s $example_in_file, 'example in fastq file exists');
my $example_out_file = $dir.'/fast_qual.example.fasta';
ok(-s $example_out_file, 'example out fasta file exists');
my $example_metrics_file = $dir.'/fast_qual.example.metrics';
ok(-s $example_metrics_file, 'example metrics file exists');
my $tmpdir = File::Temp::tempdir(CLEANUP => 1);

my $out_file = $tmpdir.'/out.fasta';
my $metrics_file = $tmpdir.'/metrics.txt';

# Resolve type from file
is(Genome::Model::Tools::FastQual->_resolve_type_for_file('a.fastq'), 'sanger', 'resolve type for fastq file');
is(Genome::Model::Tools::FastQual->_resolve_type_for_file('a.fasta'), 'phred', 'resolve type for fasta file');
is(Genome::Model::Tools::FastQual->_resolve_type_for_file('a.fna'), 'phred', 'resolve type for fna file');
is(Genome::Model::Tools::FastQual->_resolve_type_for_file('a.fa'), 'phred', 'resolve type for fa file');
ok(!Genome::Model::Tools::FastQual->_resolve_type_for_file('a.blah'), 'cannot resolve type for blah file');

# Fail: read/write to same # of inputs/outputs and same type
my $fq = Genome::Model::Tools::FastQual->execute(
    input => [ $example_in_file ],
    output => [ $out_file ],
    type_out => 'sanger',
);
ok(!$fq->result, 'failed b/c same input/output and same type');

# Success
$fq = Genome::Model::Tools::FastQual->create(
    #input => [ $dir.'/big.fastq' ],
    input => [ $example_in_file ],
    output => [ $out_file ],
    metrics_file_out => $metrics_file,
);
ok($fq, 'create w/ fastq files');
ok($fq->execute, 'execute');
is(File::Compare::compare($out_file, $example_out_file), 0, 'output file ok');
is(File::Compare::compare($metrics_file, $example_metrics_file), 0, 'metrics file ok');

# Pipes
my $fq_pipe = Genome::Model::Tools::FastQual->create();
ok($fq_pipe, 'create w/ pipes');
$fq_pipe = Genome::Model::Tools::FastQual->create(type_in => 'sanger');
ok(!$fq_pipe, 'pipe failed b/c type_in was set');
$fq_pipe = Genome::Model::Tools::FastQual->create(type_out => 'sanger');
ok(!$fq_pipe, 'pipe failed b/c type_out was set');
$fq_pipe = Genome::Model::Tools::FastQual->create(paired_input => 1);
ok(!$fq_pipe, 'pipe failed b/c paired_input was set');
$fq_pipe = Genome::Model::Tools::FastQual->create(paired_output => 1);
ok(!$fq_pipe, 'pipe failed b/c paired_output was set');

#print "$tmpdir\n"; <STDIN>;
done_testing();
exit;
    
