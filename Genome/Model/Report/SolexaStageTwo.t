#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 1;

use above "Genome";

# TODO: Fix this some how... we should create a model here rather than getting one
=cut
=cut

    my $reports_class = "Genome::Model::Report::SolexaStageTwo";
    my $report = $reports_class->create({model_id =>2722293016});
ok($report, "got a report"); 



