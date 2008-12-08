#!/gsc/bin/perl

use strict;
use warnings;

use above "Genome";

use Test::More tests => 2;

BEGIN {
    use_ok('Genome::Model::Tools::Velvet::Hash');
}

my $test_dir = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-Velvet/Hash';
my @file_names = map{$test_dir."/$_"}qw(test.fa test1.fa);
my $dir = $test_dir.'/velvet_run';

my $vh = Genome::Model::Tools::Velvet::Hash->create(
    file_names => \@file_names,
    directory  => $dir,
);

ok($vh->execute, 'velveth runs ok');

exit;
