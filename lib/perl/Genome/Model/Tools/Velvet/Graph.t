#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";

use Test::More tests => 4;
use File::Copy;

BEGIN {
    use_ok('Genome::Model::Tools::Velvet::Graph');
}

my $test_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Velvet/Graph/velvet_run';
my @files = qw(Sequences Roadmaps PreGraph Graph2);

my $tmp_dir  = File::Temp::tempdir(
    "VelvetGraph_XXXXXX", 
    DIR     => '/gsc/var/cache/testsuite/running_testsuites',
    CLEANUP => 1,
);

map{copy "$test_dir/$_", "$tmp_dir/$_"}@files;

my $vg1 = Genome::Model::Tools::Velvet::Graph->create(
    directory  => $tmp_dir,
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
    directory  => $tmp_dir,
    cov_cutoff => 6,
    amos_file  => 1,
    read_trkg  => 1,
);

ok($vg3->execute, 'velvetg runs ok, but contigs.fa is empty');

exit;
