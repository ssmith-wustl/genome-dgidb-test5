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

my $tmpdir = File::Temp::tempdir(CLEANUP => 1);

# ok - list w/ model name
my $cmd = Genome::Model::MetagenomicComposition16s::Command::ListRuns->create(
    models => [$model],
);
ok($cmd, 'create list runs');
$cmd->dump_status_messages(1);
ok($cmd->execute, 'Execute list runs ok');

done_testing();
exit;

