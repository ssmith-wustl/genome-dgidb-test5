#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

require File::Compare;
use Test::More;

# use
use_ok('Genome::Model::Tools::FastQual::Limit::ByCoverage') or die;

# create fail
ok(!Genome::Model::Tools::FastQual::Limit::ByCoverage->create(), 'Create failed w/o bases and count');
ok(!Genome::Model::Tools::FastQual::Limit::ByCoverage->create(bases => 'all'), 'Create failed  w/ bases => all');
ok(!Genome::Model::Tools::FastQual::Limit::ByCoverage->create(bases => 0), 'Create failed w/ bases => 0');
ok(!Genome::Model::Tools::FastQual::Limit::ByCoverage->create(count => 'all'), 'Create failed  w/ count => all');
ok(!Genome::Model::Tools::FastQual::Limit::ByCoverage->create(count => 0), 'Create failed w/ count => 0');

# Files
my $dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-FastQual';
my $in_fastq = $dir.'/in.fastq';
ok(-s $in_fastq, 'in fastq');
my $example_fastq = $dir.'/limit_by_coverage.example.fastq';
ok(-s $example_fastq, 'example fastq');
my $tmp_dir = File::Temp::tempdir(CLEANUP => 1);

# Ok - bases
my $out_fastq = $tmp_dir.'/out.bases.fastq';
my $limiter = Genome::Model::Tools::FastQual::Limit::ByCoverage->create(
    input  => [ $in_fastq ],
    output => [ $out_fastq ],
    bases => 92550, # 1234 sequences
);
ok($limiter, 'create limiter');
isa_ok($limiter, 'Genome::Model::Tools::FastQual::Limit::ByCoverage');
ok($limiter->execute, 'execute limiter');
is(File::Compare::compare($example_fastq, $out_fastq), 0, "fastq limited as expected");

# Ok - count
$out_fastq = $tmp_dir.'/out.count.fastq';
$limiter = Genome::Model::Tools::FastQual::Limit::ByCoverage->create(
    input  => [ $in_fastq ],
    output => [ $out_fastq ],
    count => 1234,
);
ok($limiter, 'create limiter');
isa_ok($limiter, 'Genome::Model::Tools::FastQual::Limit::ByCoverage');
ok($limiter->execute, 'execute limiter');
is(File::Compare::compare($example_fastq, $out_fastq), 0, "fastq limited as expected");

# Ok - bases and count (count will be the limiting factor)
$out_fastq = $tmp_dir.'/out.bases_and_count.fastq';
$limiter = Genome::Model::Tools::FastQual::Limit::ByCoverage->create(
    input  => [ $in_fastq ],
    output => [ $out_fastq ],
    bases => 1000000,
    count => 1234,
); 
ok($limiter, 'create limiter');
isa_ok($limiter, 'Genome::Model::Tools::FastQual::Limit::ByCoverage');
ok($limiter->execute, 'execute limiter');
is(File::Compare::compare($example_fastq, $out_fastq), 0, "fastq limited as expected");

#print "$tmp_dir\n"; <STDIN>;
done_testing();
exit;

#HeadURL$
#$Id$
