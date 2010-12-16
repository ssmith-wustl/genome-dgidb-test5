#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';
use Genome::Model::DeNovoAssembly::Test;
use Test::More;
use Data::Dumper;
require File::Compare;

use_ok('Genome::Model::Event::Build::DeNovoAssembly::Report');

my $model = Genome::Model::DeNovoAssembly::Test->get_mock_model(
    sequencing_platform => 'solexa',
    assembler_name => 'velvet one-button',
);

ok($model, 'Got mock de novo assembly model') or die;
my $build = Genome::Model::DeNovoAssembly::Test->get_mock_build(model => $model);
ok($build, 'Got mock de novo assembly build') or die;

my $example_build = Genome::Model::DeNovoAssembly::Test->get_mock_build(
    model => $model,
    use_example_directory => 1,
);
ok($example_build, 'got example build') or die;

my $example_stats_file = $example_build->stats_file;

Genome::Utility::FileSystem->create_directory($build->edit_dir);
ok(-d $build->edit_dir, "Made build edit_dir");

symlink($example_stats_file, $build->stats_file);
ok(-s $build->stats_file, "Linked stats file");

my $report = Genome::Model::Event::Build::DeNovoAssembly::Report->create(build_id => $build->id);
ok($report, "Created report");
ok($report->execute, "Executed report");

my $reports_directory = $build->reports_directory;

ok(-d $reports_directory, 'Reports directory');
ok(-s $reports_directory.'Summary/report.xml', 'Summary report XML');
ok(-s $reports_directory.'Summary/report.html', 'Summary report HTML');

done_testing();
exit;

