#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 2;
use above "Genome";

my $model_id = 2733662090; #2661729970;
my $model = Genome::Model::ReferenceAlignment->get(id => $model_id);

my $report = Genome::Model::Report::DbSnp->create(model_id => $model_id, name=> 'DbSnp');

my $snp_file = "/gscmnt/sata146/info/medseq/dlarson/GBM_Genome_Model/tumor/2733662090.snps";
$report->override_model_snp_file($snp_file);
is($report->override_model_snp_file,$snp_file,"overrode the snp file to use to be something known and short");

#$report->generate_report_brief;
my $rv = $report->generate_report_detail; 

# my $gold_snp_path = "/gscmnt/sata160/info/medseq/tcga/TCGA-06-0124/TCGA-06-0124-01A-01D.gold2";
