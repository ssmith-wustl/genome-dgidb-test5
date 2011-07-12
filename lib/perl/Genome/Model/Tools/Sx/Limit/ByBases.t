#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

require File::Compare;
use Test::More;

# use
use_ok('Genome::Model::Tools::Sx::Limit::ByBases') or die;

# fail
ok(!Genome::Model::Tools::Sx::Limit::ByBases->execute(), 'failed w/o bases');
ok(!Genome::Model::Tools::Sx::Limit::ByBases->execute(bases => 'all'), 'failed  w/ bases => all');
ok(!Genome::Model::Tools::Sx::Limit::ByBases->execute(bases => 0), 'failed w/ bases => 0');

# Files
my $dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Sx';
my $in_fastq = $dir.'/in.fastq';
ok(-s $in_fastq, 'in fastq');
my $example_fastq = $dir.'/limit_by_coverage.example.fastq';
ok(-s $example_fastq, 'example fastq');
my $tmp_dir = File::Temp::tempdir(CLEANUP => 1);

# Ok - bases
my $out_fastq = $tmp_dir.'/out.bases.fastq';
my $limiter = Genome::Model::Tools::Sx::Limit::ByBases->create(
    input  => [ $in_fastq ],
    output => [ $out_fastq ],
    bases => 92550, # 1234 sequences
);
ok($limiter, 'create limiter');
isa_ok($limiter, 'Genome::Model::Tools::Sx::Limit::ByBases');
ok($limiter->execute, 'execute limiter');
is(File::Compare::compare($example_fastq, $out_fastq), 0, "fastq limited as expected");

#print "$tmp_dir\n"; <STDIN>;
done_testing();
exit;

