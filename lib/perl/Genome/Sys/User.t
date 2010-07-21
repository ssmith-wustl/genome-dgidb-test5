#!/usr/bin/env perl
use strict;
use warnings;
use above "Genome";
use Test::More tests => 3;

use_ok("Genome::Sys::User") or die "cannot contiue w/o the user module";

my $u1 = Genome::Sys::User->get('someone@somewhere.org');
ok($u1, 'got a user object');

is($u1->id,'someone@somewhere.org');


