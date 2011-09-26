#!/usr/bin/env perl

use strict;
use warnings;

BEGIN { 
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
}

use above "Genome";

use Data::Dumper;
use Test::More;

use_ok('Genome::Project') or die;

my $user_name = Genome::Sys->username;
my $user = Genome::Sys::User->get(username => $user_name);
unless ($user) {
    $user = Genome::Sys::User->create(username => $user_name, email => "$user_name\@example.test");
}
ok($user, 'got (or created) sys user object for testing');

# create
my $project = Genome::Project->create(
    name => 'TEST AML',
);
ok($project, 'create a project');
is($project->name, 'TEST AML', 'name');
is($project->creator, $user, 'creator');
is_deeply([$project->user_ids], [$user->id], 'user ids');
my $model_group = $project->model_group;
ok($model_group, 'model group');
is($model_group->name, $project->name, 'model group name matches project name');
is($model_group->uuid, $project->id, 'model group uuid matches project id');
is($model_group->user_name, $project->creator->email, 'model group user_name matches project creator email');

# create again fails
ok(!Genome::Project->create(name => 'TEST AML'), 'failed to create project with the same name');

# create again, but since we are apipe-builder, it will rename the other project
no warnings;
my $username_sub = *Genome::Sys::username;
*Genome::Sys::username = sub{ return 'apipe-builder' };
use warnings;

my $other_user = Genome::Sys::User->get(username => Genome::Sys->username);
unless ($other_user) {
    $other_user = Genome::Sys::User->create(username => Genome::Sys->username, email => Genome::Sys->username . '@example.test');
}
ok($other_user, "created another test user");
my $project2 = Genome::Project->create(
    name => $project->name,
);
ok($project2, 'create a project');
is($project2->name, 'TEST AML', 'name');
is($project->name, $user_name.' TEST AML', 'renamed existing project made by '.$user_name);
is($model_group->name, $project->name, 'model group renamed too');
my $model_group2 = $project2->model_group;
ok($model_group2, 'model group');
is($model_group2->name, $project2->name, 'model group name matches project name');
is($model_group2->uuid, $project2->id, 'model group uuid matches project id');
is($model_group2->user_name, $project2->creator->email, 'model group user_name matches project creator email');

# rename
ok(!$project2->rename(), 'failed to rename w/o name');
ok(!$project2->rename('TEST AML'), 'failed to rename to same name');
ok($project2->rename('TEST AML1'), 'rename');
is($project2->name, 'TEST AML1', 'name after rename');

# delete
ok($project->delete, 'delete');
isa_ok($project, 'UR::DeletedRef', 'delete project');
isa_ok($model_group, 'UR::DeletedRef', 'delete model group');

done_testing();
exit;

