#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use Test::More;

use_ok('Genome::Command::Crud') or die;
use_ok('Genome::Command::Create') or die;
use_ok('Genome::Command::UpdateTree') or die;
use_ok('Genome::Command::UpdateProperty') or die;
use_ok('Genome::Command::Delete') or die;

# classes
class Person::Job {
    is => 'UR::Object',
    id_by => [
        job_id => { is => 'Number', },
    ],
    has => [
        name => { is => 'Text', },
    ],
};
sub Person::Job::__display_name__ { return $_[0]->name; }
my $president = Person::Job->create(name => 'President');
ok($president, 'create job for president');
my $vice_president = Person::Job->create(name => 'Vice President');
ok($vice_president, 'create job for vice president');
my $care_taker_of_earth = Person::Job->create(name => 'Care Taker of Earth');
ok($care_taker_of_earth, 'create job for care taker of the earth');

class Person::Relationship {
    is  => 'UR::Object',
    id_by => [
        person_id => { is => 'Number', implied_by => 'person', },
        related_id => { is => 'Number', implied_by => 'related' },
        name => { is => 'Text', },
    ],
    has => [
        person => { is => 'Person', id_by => 'person_id', },
        related => { is => 'Person', id_by => 'related_id' },
    ],
};

class Person {
    is => 'UR::Object',
    has => [
        name => { is => 'Text', doc => 'Name of the person', },
        title => {
            is => 'Text', 
            valid_values => [qw/ mr sir mrs ms miss dr /],
            default_value => 'mr',
            doc => 'Title',
        },
        has_pets => { 
            is => 'Text',
            is_optional => 1,
            valid_values => [qw/ yes no /],
            default_value => 'no',
            doc => 'Does this person have pets?', 
        },
        job => { 
            is => 'Person::Job', 
            is_optional => 1, 
            id_by => 'job_id', 
            is_optional => 1,
            doc => 'The person\'s job',
        },
        relationships => { 
            is => 'Person::Relationship',
            is_many => 1,
            is_optional => 1,
            reverse_as => 'person',
            doc => 'This person\'s relationships', 
        },
        friends => { 
            is => 'Person',
            is_many => 1,
            is_optional => 1,
            is_mutable => 1,
            via => 'relationships', 
            to => 'related',
            where => [ name => 'friend' ],
            doc => 'Friends of this person', 
        },
       mom => {
           is => 'Person',
           is_optional => 1,
           is_mutable => 1,
           is_many => 0,
           via => 'relationships', 
           to => 'related',
           where => [ name => 'mom' ],
           doc => 'The person\'s Mom', 
       },
       best_friend => {
           is => 'Person',
           is_optional => 1,
           is_mutable => 1,
           is_many => 0,
           via => 'relationships', 
           to => 'related',
           where => [ name => 'best friend' ],
           doc => 'Best friend of this person', 
       },
    ],
};
sub Person::__display_name__ {
    return $_[0]->name;
}

# INIT
my %config = (
    target_class => 'Person',
    target_name_pl => 'people',
    create => {
        before => sub{ return 'before', },
    },
    update => { only_if_null => [qw/ name mom /], include_only => [qw/ name title job has_pets mom friends best_friend /], },
);
ok(Genome::Command::Crud->init_sub_commands(%config), 'init crud commands') or die;
is_deeply([sort Person::Command->sub_command_classes], [sort map { 'Person::Command::'.$_ } (qw/ Create List Update Delete /)], 'person command classes');
print Person::Command->help_usage_complete_text;

# MAIN TREE
my $main_tree_meta = Person::Command->__meta__;
ok($main_tree_meta, 'MAIN TREE meta');
#print Person::Command->help_usage_complete_text;

# CREATE
# meta 
my $create_meta = Person::Command::Create->__meta__;
ok($create_meta, 'CREATE meta');
print Person::Command::Create->help_usage_complete_text;

is(Person::Command::Create->_target_class, 'Person', 'CREATE: _target_class');
is(Person::Command::Create->_target_name, 'person', 'CREATE: _target_name');

# fail - w/o params
my $create_fail = Person::Command::Create->create();
ok($create_fail, 'CREATE create: w/o params');
$create_fail->dump_status_messages(1);
ok(!$create_fail->execute, 'CREATE execute: failed w/o name');
$create_fail->delete;

# Create Mother Nature, the Mom
my $create_mom = Person::Command::Create->create(
    name => 'Mother Nature',
    title => 'ms',
    job => $care_taker_of_earth,
    has_pets => 'yes',
);
ok($create_mom, "CREATE create: Mom");
$create_mom->dump_status_messages(1);
is($create_mom->_before, 'before', 'CREATE mom: before create overloaded');
ok(($create_mom->execute && $create_mom->result), 'CREATE execute');
my $mom = Person->get(name => 'Mother Nature');
ok($mom, 'created Mom');
is($mom->title, 'ms', 'Mom title is ms');
is($mom->has_pets, 'yes', 'Mom has pets!');
is_deeply($mom->job, $care_taker_of_earth, 'Mom is care taker of the earth');
is_deeply([$mom->friends], [], 'Mom does not have friends');
ok(!$mom->best_friend, 'Mom does not have a best friend');

# Creater Ronnie 
my $create_ronnie = Person::Command::Create->create(
    name => 'Ronald Reagan',
    title => 'sir',
    job => $president,
    mom => $mom,
);
ok($create_ronnie, "CREATE create: Ronnie");
$create_ronnie->dump_status_messages(1);
ok(($create_ronnie->execute && $create_ronnie->result), 'CREATE execute');
my $ronnie = Person->get(name => 'Ronald Reagan');
ok($ronnie, 'created Ronnie');
is($ronnie->title, 'sir', 'Ronnie title is sir');
is($ronnie->has_pets, 'no', 'Ronnie does not have pets! Set default "no" for has pet!');
is_deeply($ronnie->job, $president, 'Ronnie is Prez');
is_deeply($ronnie->mom, $mom, 'Ronnie has a mom!');
is_deeply([$ronnie->friends], [], 'Ronnie does not have friends');
ok(!$ronnie->best_friend, 'Ronnie  does not have a best friend');

# Create George 
my $create_george = Person::Command::Create->create(
    name =>  'George HW Bush',
    title => 'mr',
    job => $vice_president,
    has_pets => 'yes', 
    best_friend => $ronnie,
    friends => [ $ronnie ],
);
ok($create_george, "CREATE create: George");
$create_george->dump_status_messages(1);
ok(($create_george->execute && $create_george->result), 'CREATE execute');
$create_george->dump_status_messages(1);
my $george = Person->get(name => 'George HW Bush');
ok($george, 'created George');
is($george->title, 'mr', 'George title is mr');
is($george->has_pets, 'yes', 'George has pets!');
is_deeply($george->job, $vice_president, 'George is vice president');
ok(!$george->mom, 'George does not have a mom');
is_deeply([$george->friends], [$ronnie], 'George has a friends');
is_deeply($george->best_friend, $ronnie, 'George is best friends w/ Ronnie');

# LIST - this is in UR::Object::Command...
my $list_meta = Person::Command::List->__meta__;
ok($list_meta, 'LIST meta');
print Person::Command::List->help_usage_complete_text;

# UPDATE
# meta
my $update_tree_meta = Person::Command::Update->__meta__;
ok($update_tree_meta, 'update tree meta');
is_deeply([Person::Command::Update->sub_command_classes], [map { 'Person::Command::Update::'.$_ } (qw/ BestFriend Friends HasPets Job Mom Name Title /)], 'update sub command classes');
print Person::Command::Update->help_usage_complete_text;
print Person::Command::Update::Title->help_usage_complete_text;
print Person::Command::Update::BestFriend->help_usage_complete_text;

# update property
# text 
my $update_title = Person::Command::Update::Title->create(
    people => [$ronnie, $george],
    value => 'mr',
);
ok($update_title, 'UPDATE PROPERTY title: create');
$update_title->dump_status_messages(1);
ok($update_title->execute, 'UPDATE PROPERTY title: execute');
is($ronnie->title, 'mr', 'UPDATE PROPERTY title: ronnie updated to mr');
is($george->title, 'mr', 'UPDATE PROPERTY title: george updated to mr');

# text w/ valid values
is($ronnie->has_pets, 'no', 'Ronnie does not have pets, but soon will!');
my $update_pets = Person::Command::Update::HasPets->create(
    people => [$ronnie],
    value => 'yes',
);
ok($update_pets, 'UPDATE PROPERTY has_pets: create');
$update_pets->dump_status_messages(1);
ok($update_pets->execute, "UPDATE PROPERTY has_pets: execute");
is($ronnie->has_pets, 'yes', 'UPDATE PROPERTY has_pets: Ronnie has pets!');

# object
my $update_job = Person::Command::Update::Job->create(
    people => [$george],
    value => $vice_president,
);
ok($update_job, 'UPDATE PROPERTY job: create');
$update_job->dump_status_messages(1);
ok(($update_job->execute && $update_job->result), 'UPDATE PROPERTY job: execute');
my @vps = Person->get(job => $vice_president);
is_deeply(\@vps, [ $george ], "UPDATE PROPERTY job: George is now VP!");

# object, only if null
ok(!$george->mom, "George does not have a mom");
my $update_mom = Person::Command::Update::Mom->create(
    people => [$george],
    value => $mom,
);
ok($update_mom, 'UPDATE PROPERTY mom: create');
$update_mom->dump_status_messages(1);
ok(($update_mom->execute && $update_mom->result), "UPDATE PROPERTY mom: execute");
is($george->mom, $mom, 'UPDATE PROPERTY mom: Geroge now has a mom');

# object, indirect
ok(!$ronnie->best_friend, "Ronnie does not have a best friend");
my $update_bf = Person::Command::Update::BestFriend->create(
    people => [$ronnie],
    value => $george,
);
ok($update_bf, 'UPDATE PROPERTY best_friend: create');
$update_bf->dump_status_messages(1);
ok(($update_bf->execute && $update_bf->result), "UPDATE PROPERTY best_friend: execute");
is_deeply($ronnie->best_friend, $george, "UPDATE PROPERTY best_friend: Ronnie is now best friends w/ George!");

# FIXME per Scott this is to fail - object to null/undef
my $update_job_null = Person::Command::Update::Job->create(
    people => [$george],
    value => '',
);
ok($update_job_null, 'UPDATE PROPERTY job: create to set undef');
$update_job_null->dump_status_messages(1);
ok(eval{(!$update_job_null->execute && !$update_job_null->result)}, 'UPDATE PROPERTY job: execute to set undef');
is_deeply($george->job, $vice_president, 'UPDATE PROPERTY job: George does not have a job.');

# FIXME per Scott this is to fail - object, single prop via a many property
my $update_bf_null = Person::Command::Update::BestFriend->create(
    people => [$ronnie],
    value => '',
);
ok($update_bf_null, 'UPDATE PROPERTY best_friend: create to set to NULL');
$update_bf_null->dump_status_messages(1);
ok(eval{(!$update_bf_null->execute && !$update_bf_null->result)}, "UPDATE PROPERTY best_friend: execute to set to NULL");
is_deeply($ronnie->best_friend, $george, "UPDATE PROPERTY best_friend: Ronnie still has a best friend");

# fail: text only if null
my $update_no_people_fail = Person::Command::Update::Name->create(
    value => 'Bob Robertson',
); 
ok($update_no_people_fail, 'UPDATE PROPERTY name: create w/o people');
$update_no_people_fail->dump_status_messages(1);
ok((!$update_no_people_fail->execute && !$update_no_people_fail->result), 'UPDATE PROPERTY name: execute failed w/o people');
$update_no_people_fail->delete;

# fail: text only if null
my $georges_name = $george->name;
my $update_name_fail = Person::Command::Update::Name->create(
    people => [$george],
    value => 'Bob Robertson',
);
ok($update_name_fail, 'UPDATE PROPERTY name: create w/o name');
$update_name_fail->dump_status_messages(1);
ok(($update_name_fail->execute && $update_name_fail->result), 'UPDATE PROPERTY name: execute fails w/o name');
is($george->name, $georges_name, 'UPDATE PROPERTY name: unchanged');
$update_name_fail->delete;

# fail: object only if null
my $ronnies_mom = $ronnie->mom;
my $update_mom_fail = Person::Command::Update::Mom->create(
    people => [$ronnie],
    value => $ronnie,
);
ok($update_mom_fail, 'UPDATE PROPERTY mom: create not null object');
$update_mom_fail->dump_status_messages(1);
ok(($update_mom_fail->execute && $update_mom_fail->result), 'UPDATE PROPERTY: execute failed b/c mom is not null');
is_deeply($ronnie->mom, $ronnies_mom, 'UPDATE PROPERTY: ronnie mom unchanged');
$update_mom_fail->delete;

# fail: valid values
my $ronnie_has_pets = $ronnie->has_pets;
my $update_pets_fail = Person::Command::Update::HasPets->create(
    people => [$ronnie],
    value => 'blah',
);
ok($update_pets_fail, 'UPDATE PROPERTY has pets: create w/ invalid value');
$update_pets_fail->dump_status_messages(1);
ok((!$update_pets_fail->execute && !$update_pets_fail->result), 'UPDATE PROPERTY has pets: execute failed b/c value was not in list');
is($ronnie->has_pets, $ronnie_has_pets, 'UPDATE PROPERTY has pets: unchanged');
$update_pets_fail->delete;

# add/remove
my $friends_tree_meta = Person::Command::Update->__meta__;
ok($friends_tree_meta, 'friends tree meta');
is_deeply([Person::Command::Update::Friends->sub_command_classes], [map { 'Person::Command::Update::Friends::'.$_ } (qw/ Add Remove /)], 'friend sub command classes');
print Person::Command::Update::Friends->help_usage_complete_text;
print Person::Command::Update::Friends::Add->help_usage_complete_text;
print Person::Command::Update::Friends::Remove->help_usage_complete_text;

my @georges_friends = $george->friends;
is_deeply(\@georges_friends, [$ronnie], 'geroge has one friend, ronnie');
my $update_add_friends = Person::Command::Update::Friends::Add->create(
    people => [$george],
    'values' => [$mom],
);
ok($update_add_friends, 'UPDATE ADD friends: create');
$update_add_friends->dump_status_messages(1);
ok(($update_add_friends->execute && $update_add_friends->result), 'UPDATE ADD friends: execute');
is_deeply([$george->friends], [$mom, @georges_friends], 'UPDATE ADD friends: added mom to georges friends');

my $update_remove_friends = Person::Command::Update::Friends::Remove->create(
    people => [$george],
    'values' => [$ronnie],
);
ok($update_remove_friends, 'UPDATE REMOVE friends: create');
$update_remove_friends->dump_status_messages(1);
ok(($update_remove_friends->execute && $update_remove_friends->result), 'UPDATE REMOVE friends: execute');
is_deeply([$george->friends], [$mom], 'UPDATE REMOVE friends: rm ronnie from georges friends');

my $update_add_fail_no_people = Person::Command::Update::Friends::Add->create(
    'values' => [$george],
);
ok($update_add_fail_no_people, 'UPDATE ADD friends: create w/o people');
$update_add_fail_no_people->dump_status_messages(1);
ok((!$update_add_fail_no_people->execute && !$update_add_fail_no_people->result), 'UPDATE ADD friends: execute fails as expected, no people');
$update_add_fail_no_people->delete;

my $update_add_fail_no_values = Person::Command::Update::Friends::Add->create(
    people => [$george],
);
ok($update_add_fail_no_values, 'UPDATE ADD friends: create w/o values');
$update_add_fail_no_values->dump_status_messages(1);
ok((!$update_add_fail_no_values->execute && !$update_add_fail_no_values->result), 'UPDATE ADD friends: execute fails as expected, no values');
$update_add_fail_no_values->delete;

# DELETE
# meta
my $delete_meta = Person::Command::Delete->__meta__;
ok($delete_meta, 'DELETE meta');
print Person::Command::Delete->help_usage_complete_text;

is(Person::Command::Delete->_target_name_pl, 'people', 'DELETE: _target_name_pl');
is(Person::Command::Delete->_target_name_pl_ub, 'people', 'DELETE: _target_name_pl_ub');

# fail w/o objects
my $delete_fail = Person::Command::Delete->create();
ok($delete_fail, 'DELETE create: No objects');
$delete_fail->dump_status_messages(1);
ok(!$delete_fail->execute, "DELETE execute: failed as expected");
$delete_fail->delete;

# success
my $delete_success = Person::Command::Delete->create(
    people => [ $george ],
);
ok($delete_success, 'DELETE create: George');
$delete_success->dump_status_messages(1);
ok($delete_success->execute, "DELETE execute");
my $deleted_jimmy = Person->get(name => 'Geroge HW Bush');
ok(!$deleted_jimmy, 'deleted George confirmed');
my @people = Person->get();
is_deeply(\@people, [ $mom, $ronnie, ], 'Mom and Ronnie still exist');

# COMMIT
ok(UR::Context->commit, 'commit');

# DISPLAY NAME
is(Genome::Command::Crud->display_name_for_value(100), 100, 'display name for "100"');
is(Genome::Command::Crud->display_name_for_value([qw/100 200/]), '100 200', 'display name for "100 200"');
is(Genome::Command::Crud->display_name_for_value([1..11]), '11 items', 'display name for more than 10 items');
is(Genome::Command::Crud->display_name_for_value($mom), $mom->name, 'display name for $mom');
is(Genome::Command::Crud->display_name_for_value([ $ronnie, $mom ]), $ronnie->name.' '.$mom->name, 'display name for [ $ronnie $mom ]');

done_testing();
exit;

