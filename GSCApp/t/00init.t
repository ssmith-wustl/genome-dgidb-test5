#! perl
# quick test script for GSCApp
use warnings;
use strict;
use Test::More tests => 2;
BEGIN { use_ok('GSCApp'); }
# at the very least this should work
ok(App->init, 'App->init');
exit(0);

# $Header$
