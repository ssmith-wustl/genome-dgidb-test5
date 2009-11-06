#!/gsc/bin/perl

use strict;
use warnings;

use lib '/gscuser/edemello/svn/fresh4/trunk/Genome/Model/Tools/';
use above 'Genome';
use Test::More tests => 3;


BEGIN {use_ok('Genome::Model::Tools::ContaminationScreen::MegaBlast');}

my %params;
 $params{input_file} = '/gsc/var/tmp/fasta/MegaBlast/test_nt.fna';
$params{output_file} = '/gsc/var/tmp/fasta/MegaBlast/test_output.fna';
$params{database} = '/gscmnt/sata837/assembly/nt_db/genbank_nt_20091004'; 
$params{header} = '/gsc/var/tmp/fasta/MegaBlast/nt.index.header';

my $hcs_MegaBlast = Genome::Model::Tools::ContaminationScreen::MegaBlast->create(%params);

isa_ok($hcs_MegaBlast, 'Genome::Model::Tools::ContaminationScreen::MegaBlast');

ok($hcs_MegaBlast->execute, "MegaBlast executing");
