#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 1;

use above "Genome";

# TODO: Fix this some how... we should create a model here rather than getting one
=cut
=cut
    my $html_rpt = Genome::Model::Report->create(model_id => 2722293016, name => "Table");


    ok($html_rpt, "got report");
