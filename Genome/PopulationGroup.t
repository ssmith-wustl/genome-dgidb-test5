#!/usr/bin/env perl
use strict;
use warnings;
use above "Genome";
#use Test::More tests => 5;
use Test::More skip_all => 'LIMS now requires a PSE to create a GSC::PopulationGroup';

use_ok("Genome::PopulationGroup");

my $p = Genome::PopulationGroup->create(
    id => -123,
    name => "test pop"
);
ok($p,"got a test population group");

my $d = GSC::PopulationGroup->is_loaded($p->id);
ok($d, "found delegate object");

is($p->name,'test pop', "name is as expected");
is($p->name,$d->name, "names match");

