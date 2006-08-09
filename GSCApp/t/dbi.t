#! perl
# test script for GSCApp::DBI
use warnings;
use strict;
use Test::More tests => 5;
BEGIN { use_ok('GSCApp'); }
# at the very least this should work
ok(App->init, 'App->init');
my $login = 'rwilson';
my $uid = getpwnam($login);
ok($uid, "got uid for $login: $uid");
# get employee id
my $id = App::DB->dbh->employee_id($uid);
ok($id, "got ei_id for $uid: $id");
my $rwilson_id = 300;
cmp_ok($id, '==', $rwilson_id, "$login id is correct");
exit(0);

# $Header$
