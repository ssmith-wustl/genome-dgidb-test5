#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';
use Test::More tests => 2;

BEGIN {use_ok('Genome::Model::Tools::ContaminationScreen::Hmp::Illumina');}

my %params;
$params{dir} = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-ContaminationScreen-Hmp-Illumina';#
$params{fastq1} = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-ContaminationScreen-Hmp-Illumina/solexa-fastq-contam0'; 
$params{fastq2} = '/gsc/var/cache/testsuite/data/Genome-Model-Tools-ContaminationScreen-Hmp-Illumina/solexa-fastq-contam1';

my $illumina = Genome::Model::Tools::ContaminationScreen::Hmp::Illumina->create(%params);

isa_ok($illumina, 'Genome::Model::Tools::ContaminationScreen::Hmp::Illumina');

#$illumina->execute();
