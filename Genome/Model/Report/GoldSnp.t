#!/usr/bin/env perl

use strict;
use warnings;

use Test::More skip_all => 1;#tests => 1;

use above "Genome";

# TODO: Fix this some how... we should create a model here rather than getting one
=cut
=cut
    my $model_id = 2733662090;#2661729970;
    my $gold_snp_path = "/gscmnt/sata160/info/medseq/tcga/TCGA-06-0124/TCGA-06-0124-01A-01D.gold2";
    my $snp_file = "/gscmnt/sata146/info/medseq/dlarson/GBM_Genome_Model/tumor/2733662090.snps";

    my $model = Genome::Model->get(genome_model_id=>$model_id);
    ok($model, "got a model");
    $model->gold_snp_path($gold_snp_path);

    my ($id, $name) = ($model_id,'GoldSnp');
    my $report = Genome::Model::Report::GoldSnp->create(model_id =>$id, name=>$name);

    ok($report, "got a report");
    $report->snp_file($snp_file);   
    $report->generate_report_detail;

