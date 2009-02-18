#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 2;

use above "Genome";

=cut
=cut

    my $gold_snp_path = "/gscmnt/sata160/info/medseq/tcga/TCGA-06-0124/TCGA-06-0124-01A-01D.gold2";
    my $snp_file = "/gscmnt/sata146/info/medseq/dlarson/GBM_Genome_Model/tumor/2733662090.snps";

    my $build_id = 93293206;
    my $build = Genome::Model::Build->get(build_id => $build_id);
    ok($build, "got a build");

    my ($id, $name) = ($build_id,'GoldSnp');
    my $report = Genome::Model::Report->create(build_id => $id, name=>$name);

    ok($report, "got a report");

