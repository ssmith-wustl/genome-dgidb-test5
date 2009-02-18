#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 2;

use above "Genome";

my $snp_file = "/gscmnt/sata146/info/medseq/dlarson/GBM_Genome_Model/tumor/2733662090.snps";

my $build_id = 93293206;
my $build = Genome::Model::Build->get(build_id => $build_id);
ok($build, "got a build");

my ($id, $name) = ($build_id,'DbSnp');
my $report = Genome::Model::Report->create(build_id =>$id, name=>$name);

ok($report, "got a report");

