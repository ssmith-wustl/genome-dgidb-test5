#!/usr/bin/env perl
use strict;
use warnings;

$ENV{UR_DBI_NO_COMMIT} = 1;

use above "Genome";
use Test::More tests => 7;

use_ok('Genome::ModelGroup');

my $model_group = Genome::ModelGroup->create(
  id => -12345,
  name => 'Testsuite ModelGroup',
);

ok($model_group, 'Got a model_group');
isa_ok($model_group, 'Genome::ModelGroup');

my $test_model = Genome::Model->create_mock(
    genome_model_id => -1234567,
    name => 'Test ModelGroup Member Model',
    processing_profile_id => -1,
    subject_name => 'ModelGroup Test Subject',
    subject_type => 'Fake',
    id => -1234567,
);

my $test_model_two = Genome::Model->create_mock(
    genome_model_id => -76543210,
    name => 'Test ModelGroup Member Model Two',
    processing_profile_id => -1,
    subject_name => 'ModelGroup Test Subject Two',
    subject_type => 'Fake',
    id => -76543210,
);

my $add_command = Genome::ModelGroup::Command::Member::Add->create(
    model_group_id => $model_group->id,
    model_ids => join(',', $test_model_two->id, $test_model->id),
);

ok($add_command, 'created member add command');
ok($add_command->execute(), 'executed member add command');

my $remove_command = Genome::ModelGroup::Command::Member::Remove->create(
    model_group_id => $model_group->id,
    model_ids => $test_model->id
);

ok($remove_command, 'created member remove command');
ok($remove_command->execute(), 'executed member remove command');
