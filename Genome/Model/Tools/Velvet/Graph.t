#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";

use Test::More tests => 4;

BEGIN {
    use_ok('Genome::Model::Tools::Velvet::Graph');
}

my $test_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Velvet/Graph';
my $dir = $test_dir.'/velvet_run';

my $vg1 = Genome::Model::Tools::Velvet::Graph->create(
    directory  => $dir,
    cov_cutoff => 3.3,
    amos_file  => 1,
    read_trkg  => 1,
);

ok($vg1->execute, 'velvetg runs ok');

my $vg2 = Genome::Model::Tools::Velvet::Graph->create(
    cov_cutoff => 3.3,
    amos_file  => 1,
    read_trkg  => 1,
);

ok(!$vg2, 'default dir does not exist');

my $vg3 = Genome::Model::Tools::Velvet::Graph->create(
    directory  => $dir,
    cov_cutoff => 6,
    amos_file  => 1,
    read_trkg  => 1,
);

ok($vg3->execute, 'velvetg runs ok, but contigs.fa is empty');

my @outputs = map{$dir."/$_"}qw(Log contigs.fa LastGraph stats.txt stats.txt.prev velvet_asm.afg);
map{unlink}@outputs;

exit;
