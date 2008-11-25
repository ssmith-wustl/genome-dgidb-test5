#!/usr/bin/env perl

use strict;
use warnings;

use above "Genome";
use Test::More tests => 2;

my $m = Genome::Model->get(id =>2722293016);

ok($m, "got a model"); 

my @reports = @{$m->available_reports};

ok(@reports, "got reports");


