#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More;
use Genome::Model::DeNovoAssembly::Test;

use_ok('Genome::Model::Build::DeNovoAssembly::Soap') or die;

my $model = Genome::Model::DeNovoAssembly::Test->get_mock_model(
    sequencing_platform => 'solexa',
    assembler_name => 'soap',
);
ok($model, 'Got mock de novo assembly model') or die;
my $build = Genome::Model::DeNovoAssembly::Test->get_mock_build(
    model => $model,
    use_example_directory => 1,
);
ok($build, 'example build');

my $file_prefix = $build->file_prefix;
is($file_prefix, $model->subject_name.'_WUGC', 'file prefix');

# edit dir files
my %files_to;

done_testing();
exit;
