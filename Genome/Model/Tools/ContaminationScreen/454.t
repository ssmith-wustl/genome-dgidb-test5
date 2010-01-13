#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';
use Test::More tests => 2;

BEGIN {use_ok('Genome::Model::Tools::ContaminationScreen::454');}

my %params;
$params{input_file} = '/gsc/var/tmp/fasta/454/test.fna';
$params{database} = '/gscmnt/sata156/research/mmitreva/databases/human_build36/HS36.chr_Mt_ribo.fna';
my $hcs_454 = Genome::Model::Tools::ContaminationScreen::454->create(%params);

isa_ok($hcs_454, 'Genome::Model::Tools::ContaminationScreen::454');




