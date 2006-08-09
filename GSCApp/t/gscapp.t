#! perl
# quick test script for GSCApp
use warnings;
use strict;
use Test::More tests => 5;
BEGIN { use_ok('GSCApp'); }
# at the very least this should work
ok(App->init, 'App->init');
my $id = 10001;
my $c = GSC::Clone->get($id);
ok($c, "got clone $id");
ok(ref($c) eq 'GSC::Clone', 'clone is a GSC::Clone');
my $name = 'H_NH0319A07';
ok($name eq $c->clone_name, "clone name is $name");
exit(0);

# $Header$
