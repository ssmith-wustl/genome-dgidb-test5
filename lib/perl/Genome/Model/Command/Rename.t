#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Test::More;

use_ok('Genome::Model::Command::Rename') or die;

class Genome::Model::Tester {
    is => 'Genome::Model',
};
class Genome::ProcessingProfile::Tester {
    is => 'Genome::ProcessingProfile',
};

my $model = Genome::Model::Tester->create(
    name => '__TEST__MODEL__',
    subject => Genome::Sample->create(name => '__TEST__SAMPLE__'),
    processing_profile => Genome::ProcessingProfile::Tester->create(name => '__TEST__PP__'),
);
ok($model, 'create model') or die;

my $new_name = '__RENAME__';
my $old_name = $model->name;

# SUCCESS
my $renamer = Genome::Model::Command::Rename->create(
    from => $model,
    to => $new_name,
);
$renamer->dump_status_messages(1);
ok($renamer->execute, 'execute');
is($model->name, $new_name, 'renamed model');
$model->name($old_name); # reset for testing below

# FAIL
# no name
ok(!Genome::Model::Command::Rename->execute(from => $model), 'Failed - create w/o new name');
# create and execute w/ same name
$renamer = Genome::Model::Command::Rename->create(from => $model, to => $old_name);
ok(!$renamer->execute, 'Failed - execute w/ same name');

done_testing();
exit;

