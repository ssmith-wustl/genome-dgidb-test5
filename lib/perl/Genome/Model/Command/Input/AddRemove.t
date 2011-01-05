#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
require Genome::Model::Test;
use Test::More;

# USE
use_ok('Genome::Model::Command::Input::Add') or die;
use_ok('Genome::Model::Command::Input::Remove') or die;

# MODEL
my $model = Genome::Model::Test->create_mock_model(
    type_name => 'tester',
    instrument_data_count => 0,
) or die "Can't create mock tester model.";
ok($model, 'got model') or die 'Cannot get mock model';

# ADD
note('Add single value');
my $add = Genome::Model::Command::Input::Add->create(
    model => $model,
    name => 'inst_data',
    'values' => [qw/ 2sep09.934pmaa1 /],
);
ok($add, 'create');
$add->dump_status_messages(1);
my @inst_data= $model->inst_data;
ok(!@inst_data, 'no inst_data');
ok($add->execute, 'execute');
@inst_data= $model->inst_data;
ok(@inst_data, 'added inst_data');

note('Add multiple values');
$add = Genome::Model::Command::Input::Add->create(
    model => $model,
    name => 'friends',
    'values' => [qw/ Watson Crick /],
);
ok($add, 'create');
my @friends = $model->friends;
ok(!@friends, 'no friends');
$add->dump_status_messages(1);
ok($add->execute, 'execute');
@friends = $model->friends;
ok(@friends, 'added friends');

note('Fail - add singlular property');
$add = Genome::Model::Command::Input::Add->create(
    model => $model,
    name => 'coolness', 
    'values' => [qw/ none /],
);
ok($add, 'create');
$add->dump_status_messages(1);
ok(!$add->execute, 'execute');

note('Fail - Add already existing friend');
$add = Genome::Model::Command::Input::Add->create(
    model => $model,
    name => 'friends',
    'values' => [qw/ Crick /],
);
ok($add, 'create');
$add->dump_status_messages(1);
ok(!$add->execute, 'execute');

note('Fail - input object does exist');
$add = Genome::Model::Command::Input::Add->create(
    model => $model,
    name => 'inst_data',
    'values' =>[qw/ 2sep09.934noexist /],
);
ok($add, 'create');
$add->dump_status_messages(1);
ok(!$add->execute, 'execute');

# REMOVE
my $remove =Genome::Model::Command::Input::Remove->create(
    model => $model,
    name => 'friends',
    'values' => [qw/ Watson Crick /],
);
ok($remove, 'create');
@friends = $model->friends;
ok(@friends, 'model has friends');
ok($remove->execute);
@friends = $model->friends;
ok(!@friends, 'removed friends');


note('Remove single value, and abandon builds');
# mock abandon on build
my $build = ($model->builds)[0];
$build->mock('abandon', sub{ return $build->build_event->event_status('Abandoned'); });
# add input to build
my $build_input = Genome::Utility::TestBase->create_mock_object(
    class => 'Genome::Model::Build::Input',
    name => 'instrument_data',
    value_id => '2sep09.934pmaa1',
    build_id => $build->id,
);
ok($build_input, 'added inst_data to build');
$remove =Genome::Model::Command::Input::Remove->create(
    model => $model,
    name => 'inst_data',
    'values' => [qw/ 2sep09.934pmaa1 /],
    abandon_builds => 1,
);
@inst_data = $model->inst_data;
ok(@inst_data, 'model has inst_data');
ok($remove, 'create');
ok($remove->execute);
@inst_data = $model->inst_data;
ok(!@inst_data, 'removed inst_data');

note('Fail - remove singlular property');
$remove =Genome::Model::Command::Input::Remove->create(
    model => $model,
    name => 'coolness', 
    'values' => [qw/ none /],
);
ok($remove, 'create');
ok(!$remove->execute);

note('Fail - remove input not linked anymore');
$remove =Genome::Model::Command::Input::Remove->create(
    model => $model,
    name => 'inst_data',
    'values' => [qw/ 2sep09.934pmaa1 /],
);
ok($remove, 'create');
ok(!$remove->execute);

sub _startup {
    my $self = shift;

    my $model = $self->_model;

    $model->add_friend('Crick');
    $model->add_friend('Watson');
    my @friends = $model->friends();
    is_deeply(\@friends, [qw/ Crick Watson /], 'Added friends to remove.');
    my $id = Genome::InstrumentData::Sanger->get('2sep09.934pmaa1')
        or die "Can't get sange id 2sep09.934pmaa1";
    $model->add_inst_data($id);
    my @inst_data = $model->inst_data;
    is_deeply(\@inst_data, [ $id ], 'Added instr_data to remove');
    
 
    return 1;
}

done_testing();
exit;

=pod

=head1 Tests

=head1 Disclaimer

 Copyright (C) 2009 Washington University Genome Sequencing Center

 This script is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author(s)

 Eddie Belter <ebelter@watson.wustl.edu>

=cut

