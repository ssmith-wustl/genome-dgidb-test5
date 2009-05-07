#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';
use Test::More tests => 3;


BEGIN {use_ok('Genome::Model::Tools::ContaminationScreen::3730');}

my %params;
$params{input_file} = '/gsc/var/tmp/fasta/3730/test.fna';
$params{output_file} = '/gsc/var/tmp/fasta/3730/output.fna';
$params{database} = '/gscmnt/sata156/research/mmitreva/databases/human_build36/HS36.chr_Mt_ribo.fna';

my $hcs_3730 = Genome::Model::Tools::ContaminationScreen::3730->create(%params);

isa_ok($hcs_3730, 'Genome::Model::Tools::ContaminationScreen::3730');

ok($hcs_3730->execute, "3730 executing");




