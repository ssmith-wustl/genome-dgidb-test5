#!/usr/bin/env perl

use strict;
use warnings;
use lib '/edemello/svn/fresh2';

use Test::More tests => 3;

use above "Genome";

my $build_id = 93293206;
my $build = Genome::Model::Build->get(build_id => $build_id);
ok($build, "got a build");

my ($id, $name, $snp_file) = ($build_id,'DbSnp', '/gscmnt/sata363/info/medseq/model_data/2733662090/build93293206/reports/DbSnp/trunc.snp');
my $report = Genome::Model::Report->create(build_id =>$id, name=>$name, override_model_snp_file=>$snp_file);

ok($report, "got a report object");

$report->generate_report_detail;

ok ($report->report_detail_output_filename, "got detailed output");


