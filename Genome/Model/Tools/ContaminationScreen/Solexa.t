#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';
use Test::More tests => 3;


BEGIN {use_ok('Genome::Model::Tools::ContaminationScreen::Solexa');}

my %params;
$params{input_file} = '/gsc/var/tmp/fasta/Solexa/test3.fna';
$params{database} = '/gsc/var/tmp/fasta/Solexa/test2.fna';
$params{minscore} = 42;

my $solexa = Genome::Model::Tools::ContaminationScreen::Solexa->create(%params);

isa_ok($solexa, 'Genome::Model::Tools::ContaminationScreen::Solexa');

ok($solexa->execute, "solexa executing");



