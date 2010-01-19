#!/gsc/bin/perl

use strict;
use warnings;

use above 'Genome';
use Test::More tests => 2;


BEGIN {use_ok('Genome::Model::Tools::ContaminationScreen::Hmp::Illumina');}

my %params;
$params{dir} = '/gsc/var/tmp/fasta/Hmp/illumina/paired/contam';
$params{fastq1} = '/gscmnt/sata810/info/medseq/chiptest/chiptest2_250k_gbm/chiptest_gbm51_contam/solexa-fastq-contam0'; 
$params{fastq2} = '/gscmnt/sata810/info/medseq/chiptest/chiptest2_250k_gbm/chiptest_gbm51_contam/solexa-fastq-contam1';

my $illumina = Genome::Model::Tools::ContaminationScreen::Hmp::Illumina->create(%params);

isa_ok($illumina, 'Genome::Model::Tools::ContaminationScreen::Hmp::Illumina');

