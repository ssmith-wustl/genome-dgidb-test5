#!/usr/bin/env perl
use strict;
use warnings;
use above "Genome";
use Test::More tests => 4;

use_ok("Genome::Sys::User") or die "cannot contiue w/o the user module";

my $u0 = Genome::Sys::User->create(
    email => 'someone@somewhere.org',
    name => 'Fake McFakerston'
);

ok($u0,'create a user object');

my $u1 = Genome::Sys::User->get(email => 'someone@somewhere.org');
ok($u1, 'got a user object');

is($u1->id,'someone@somewhere.org');


