#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use Genome::Model::Test;
use Genome::Model::MetagenomicComposition16s::Test;
use Test::More;

use_ok('Genome::Model::MetagenomicComposition16s::Command::ListRuns') or die;

# model/build
my $model = Genome::Model::MetagenomicComposition16s::Test->model_for_sanger;
ok($model, 'Got mock mc16s sanger model');
my $build = Genome::Model::MetagenomicComposition16s::Test->example_build_for_model($model);
ok($build, 'Got mock mc16s build');

my $cmd;
my $tmpdir = File::Temp::tempdir(CLEANUP => 1);

# ok - list w/ model name
$cmd = Genome::Model::MetagenomicComposition16s::Command::ListRuns->execute(
    build_identifiers => $model->name,
);
ok(
    $cmd && $cmd->result,
    'Execute list runs ok',
);

done_testing();
exit;

