#!/usr/bin/env perl

use strict;
use warnings;

use above "Genome";
use Test::More tests => 14;

my $m = Genome::Model->get(id => 2721044485);
ok($m, "got a model"); 

my @reports = @{$m->available_reports};

ok(@reports, "got reports");

foreach my $r (@reports) {
    ok( $r->name eq 'SolexaStageOne', 'got correct report name');
}

