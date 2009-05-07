#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';
use Test::More tests => 3;


BEGIN {use_ok('Genome::Model::Tools::ContaminationScreen::Solexa');}

my %params;
$params{input_file} = '/gsc/var/tmp/fasta/Solexa/test3.fna';
#$params{output_file} = 'gsc/var/tmp/fasta/Solexa/output.fna';
$params{database} = '/gsc/var/tmp/fasta/Solexa/test2.fna';#'/gscmnt/sata156/research/mmitreva/databases/human_build36/HS36.chr_Mt_ribo.fna';
my $solexa = Genome::Model::Tools::ContaminationScreen::Solexa->create(%params);

isa_ok($solexa, 'Genome::Model::Tools::ContaminationScreen::Solexa');

ok($solexa->execute, "solexa executing");



