#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use Genome::Model::Test;
use Genome::Model::MetagenomicComposition16s::Test;
use Test::More;

use_ok('Genome::Model::MetagenomicComposition16s::Command::CopyFiles') or die;

# model/build
my $model = Genome::Model::MetagenomicComposition16s::Test->model_for_sanger;
ok($model, 'Got mock mc16s sanger model');
my $build = Genome::Model::MetagenomicComposition16s::Test->example_build_for_model($model);
ok($build, 'Got mock mc16s build');

my $copy_cmd;
my $tmpdir = File::Temp::tempdir(CLEANUP => 1);

# ok - list w/ model name
$copy_cmd = Genome::Model::MetagenomicComposition16s::Command::CopyFiles->execute(
    build_identifiers => $model->name,
    file_type => 'oriented_fasta',
    list => 1,
);
ok(
    $copy_cmd && $copy_cmd->result,
    'Execute list ok',
);

# ok - copy
#  tests multiple build retrieving methods: model id and build id
$copy_cmd = Genome::Model::MetagenomicComposition16s::Command::CopyFiles->execute(
    build_identifiers => $model->id,
    file_type => 'processed_fasta',
    destination => $tmpdir,
);
ok(
    $copy_cmd && $copy_cmd->result,
    'Execute copy ok',
);
my @files = glob("$tmpdir/*");
is(scalar @files, 1, 'Copied files');

# fail - copy to existing
$copy_cmd = Genome::Model::MetagenomicComposition16s::Command::CopyFiles->execute(
    build_identifiers => $model->id,
    file_type => 'processed_fasta',
    destination => $tmpdir,
);
ok(
    $copy_cmd && !$copy_cmd->result,
    'Failed as expected - no copy to existing file',
);

# ok - force copy
$copy_cmd = Genome::Model::MetagenomicComposition16s::Command::CopyFiles->execute(
    build_identifiers => $model->id,
    file_type => 'processed_fasta',
    destination => $tmpdir,
    force => 1,
);
ok(
    $copy_cmd && $copy_cmd->result,
    'Execute copy ok',
);

# fail - no type
ok(
    !Genome::Model::MetagenomicComposition16s::Command::CopyFiles->execute(
        build_identifiers => $model->id,
    ),
    'Failed as expected - no type',
);

# fail - invalid type
ok(
    !Genome::Model::MetagenomicComposition16s::Command::CopyFiles->execute(
        build_identifiers => $model->id,
        file_type => 'some_file_type_that_is_not_valid',
    ),
    'Failed as expected - no type',
);

done_testing();
exit;

