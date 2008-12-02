#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 1;

use above "Genome";

BEGIN {
   # use_ok('Genome::Model::Report::SolexaStageTwo');
}

# TODO: Fix this some how... we should create a model here rather than getting one
=cut
=cut

    my ($id, $name) = (2722293016,'SolexaStageTwo');
    my $report = Genome::Model::Report->create(model_id =>$id,name=>$name);
ok($report, "got a report"); 





