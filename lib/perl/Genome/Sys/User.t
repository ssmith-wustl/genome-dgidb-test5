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

my $project = Genome::Project->create(name => 'user_test_project');
$project->add_part(entity => $u1);
my ($self_project) = Genome::Sys::User->get(username => Genome::Sys->username())->projects;
is_deeply($self_project, $project, "Got project from project creator");
my ($user_project) = $u1->projects;
is_deeply($user_project, $project, "Got project from user part");


