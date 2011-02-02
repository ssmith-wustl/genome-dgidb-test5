#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use Test::More;

use_ok('Genome::Command::Crud') or die;
use_ok('Genome::Command::Create') or die;
use_ok('Genome::Command::Update') or die;
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
       mom => { is => 'Person', id_by => 'mom_id', },
       mom_id => {
           is => 'Number',
           is_optional => 1,
           is_mutable => 1,
           is_many => 0,
           via => 'relationships', 
           to => 'related_id',
           where => [ name => 'mom' ],
           doc => 'The person\'s Mom', 
       },
       best_friend => { is => 'Person', id_by => 'best_friend_id', },
       best_friend_id => {
           is => 'Number',
           is_optional => 1,
           is_mutable => 1,
           is_many => 0,
           via => 'relationships', 
           to => 'related_id',
           where => [ name => 'best friend' ],
           doc => 'Best friend of this person', 
       },
    ],
};
sub Person::__display_name__ {
    return $_[0]->name;
}

class Person::Command {
    is => 'Command',
};

# INIT
my %config = (
    target_class => 'Person',
    update => { only_if_null => [qw/ job title mom /], },
);
ok(Genome::Command::Crud->init_sub_commands(%config), 'init crud commands') or die;

# CREATE
# class meta and properties
my $create_meta = Person::Command::Create->__meta__;
ok($create_meta, 'create meta');
#my @property_metas = grep { $_->{class_name} eq 'Person::Command::Create' } $create_meta->property_metas;
#ok(@property_metas, 'create property metas');
#print Dumper([map { $_->property_name } @property_metas]);
print Person::Command::Create->help_usage_complete_text;

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
ok(!$george->job, 'George does not have a job');
ok(!$george->mom, 'George does not have a mom');
is_deeply([$george->friends], [$ronnie], 'George has a friends');
is_deeply($george->best_friend, $ronnie, 'George is best friends w/ Ronnie');

# LIST - this is in UR::Object::Command...
my $list_meta = Person::Command::List->__meta__;
ok($list_meta, 'list meta');

# UPDATE
my $update_meta = Person::Command::Update->__meta__;
ok($update_meta, 'update meta');
print Person::Command::Update->help_usage_complete_text;

# fail w/o objects
my $update_fail = Person::Command::Update->create();
ok($update_fail, 'UPDATE COMMAND: create w/o persons');
$update_fail->dump_status_messages(1);
ok((!$update_fail->execute && !$update_fail->result), 'UPDATE COMMAND: failed execute as expected');
$update_fail->delete;

# fail w/o prop to update
$update_fail = Person::Command::Update->create(
    persons => [ $ronnie ],
);
ok($update_fail, 'UPDATE COMMAND: create w/o property');
$update_fail->dump_status_messages(1);
ok(!$update_fail->execute, 'UPDATE COMMAND: failed execute as expected');
$update_fail->delete;

# fail to update non null property that is text (title)
my $old_title = $ronnie->title;
$update_fail = Person::Command::Update->create(
    persons => [ $ronnie ],
    title => 'dr',
);
ok($update_fail, 'UPDATE COMMAND: create attempt to update not null property (text)');
$update_fail->dump_status_messages(1);
ok((!$update_fail->execute && !$update_fail->result), 'UPDATE COMMAND: execute');
is($ronnie->title, $old_title, 'Ronnie title not updated b/c it was not null');
$update_fail->delete;

# fail to update non null property that is an object 
$update_fail = Person::Command::Update->create(
    persons => [ $ronnie ],
    mom => $george,
);
ok($update_fail, 'UPDATE COMMAND: create attempt to update not null property (object)');
$update_fail->dump_status_messages(1);
ok((!$update_fail->execute && !$update_fail->result), 'UPDATE COMMAND: execute');
is($ronnie->mom, $mom, 'Ronnie mom not updated b/c it was not null');
$update_fail->delete;

# fail to update title not in valid values
my $has_pets = $ronnie->has_pets;
$update_fail = Person::Command::Update->create(
    persons => [ $ronnie ],
    has_pets => 'blah',
);
ok($update_fail, 'UPDATE create: Ronnie set has_pets to blah');
$update_fail->dump_status_messages(1);
ok(!$update_fail->execute, 'UPDATE execute: failed as expected');
is($ronnie->has_pets, $has_pets, 'Ronnie has_pets was not updated b/c "blah" was not in list of valid values');
$update_fail->delete;

# update has pets (text)
is($ronnie->has_pets, 'no', 'Ronnie does not have pets, but soon will!');
my $update_success = Person::Command::Update->create(
    persons => [ $ronnie ],
    has_pets => 'yes',
);
ok($update_success, 'UPDATE create" Ronnie set has_pets to yes');
$update_success->dump_status_messages(1);
ok($update_success->execute, "UPDATE execute");
is($ronnie->has_pets, 'yes', 'Ronnie has pets!');

# update job (direct object)
$update_success = Person::Command::Update->create(
    persons => [ $george ],
    job => $vice_president,
);
ok($update_success, 'UPDATE create: w/ job vp');
$update_success->dump_status_messages(1);
ok(($update_success->execute && $update_success->result), 'UPDATE execute');
my @vps = Person->get(job => $vice_president);
is_deeply(\@vps, [ $george ], "George is now VP!");

# update 2 things at a time - add friend and best friend
is_deeply([ $ronnie->friends ], [ ], "Ronnie does not have any friends");
ok(!$ronnie->best_friend, "Ronnie does not have a best friend");
$update_success = Person::Command::Update->create(
    persons => [ $ronnie ],
    add_friend => $george,
    best_friend => $george,
);
ok($update_success, 'UPDATE create: Give Ronnie a friend');
$update_success->dump_status_messages(1);
ok(($update_success->execute && $update_success->result), "UPDATE execute");
is_deeply([$ronnie->friends], [$george], "Ronnie is now friends w/ George!");
is_deeply($ronnie->best_friend, $george, "Ronnie is now best friends w/ George!");

# update mom - this is update only if null, and George does not have a mom
ok(!$george->mom, "Georege does not have a mom");
$update_success = Person::Command::Update->create(
    persons => [ $george ],
    mom => $mom,
);
ok($update_success, 'UPDATE create: Give Georege a mom');
$update_success->dump_status_messages(1);
ok(($update_success->execute && $update_success->result), "UPDATE execute");
is($george->mom, $mom, 'Geroge now has a mom');

# DELETE
# fail w/o objects
my $delete_fail = Person::Command::Delete->create();
ok($delete_fail, 'DELETE create: No objects');
$delete_fail->dump_status_messages(1);
ok(!$delete_fail->execute, "DELETE execute: failed as expected");
$delete_fail->delete;

# success
my $delete_success = Person::Command::Delete->create(
    persons => [ $george ],
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

done_testing();
exit;

=pod

=head1 Disclaimer

 Copyright (C) 2011 Washington University Genome Sequencing Center

 This script is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author(s)

 Eddie Belter <ebelter@watson.wustl.edu>

=cut
