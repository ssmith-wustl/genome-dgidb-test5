#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
require Genome::Model::Test;
use Test::More;

use_ok('Genome::Model::Command::Input::Update') or die;

my $model = Genome::Model->get(2857912274); # apipe-test-05-de_novo_velvet_solexa
ok($model, 'got model') or die;

my $update = Genome::Model::Command::Input::Update->create(
    model => $model,
    name => 'center_name',
    value => 'Baylor',
);
ok($update, 'create');
$update->dump_status_messages(1);
ok($update->execute, 'execute');

note('Update to undef');
$update = Genome::Model::Command::Input::Update->create(
    model => $model,
    name => 'center_name',
    value => '',
);
ok($update, 'create');
$update->dump_status_messages(1);
ok($update->execute, 'execute');

note('Try to use update for is_many property');
$update = Genome::Model::Command::Input::Update->create(
    model => $model,
    name => 'instrument_data',
    value => 'Watson',
);
ok($update, 'create');
$update->dump_status_messages(1);
ok(!$update->execute, 'execute');

done_testing();
exit;

