#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 1;

use above "Genome";

# TODO: Fix this some how... we should create a model here rather than getting one
=cut
=cut

    my ($id, $name) = (2661729970,'SolexaStageOne');
    my $report = Genome::Model::Report->create(model_id =>$id,name=>$name);
ok($report, "got a report"); 



$report->generate_report_detail();
$report->generate_report_brief();

