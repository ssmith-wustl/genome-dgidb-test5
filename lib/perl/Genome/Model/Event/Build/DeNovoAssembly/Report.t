#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';
use Genome::Model::DeNovoAssembly::Test;
use Test::More;
use Data::Dumper;
require File::Compare;

use_ok('Genome::Model::Event::Build::DeNovoAssembly::Report');
#< velvet test >#
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

Genome::Sys->create_directory($build->edit_dir);
ok(-d $build->edit_dir, "Made build edit_dir");

#link build dir files
my @build_file_accessor_methods = qw/
     assembly_afg_file
     sequences_file
/;

for my $method ( @build_file_accessor_methods ) {
    symlink( $example_build->$method, $build->$method );
    ok ( -e $build->$method, "Linked file from method: $method");
}

#link edit_dir files for stats
my @edit_dir_file_accessor_methods = qw/
    contigs_bases_file
    contigs_quals_file
    gap_file
    read_info_file
    reads_placed_file
/;
for my $method ( @edit_dir_file_accessor_methods ) {
    symlink( $example_build->$method, $build->$method );
    ok ( -e $build->$method, "Linked file from method: $method");
}

#additional files #TODO - method to get these files
for my $file ( qw/ H_GV-933124G-S.MOCK.collated.fasta.gz H_GV-933124G-S.MOCK.collated.fasta.qual.gz / ) {
    symlink( $example_build->data_directory."/edit_dir/$file", $build->edit_dir."/$file" );
    ok( -e $build->edit_dir."/$file", "Linked $file" );
}

my $report = Genome::Model::Event::Build::DeNovoAssembly::Report->create(build_id => $build->id);
ok($report, "Created report");
ok($report->execute, "Executed report");

my $reports_directory = $build->reports_directory;

ok(-d $reports_directory, 'Reports directory');
ok(-s $reports_directory.'Summary/report.xml', 'Summary report XML');
ok(-s $reports_directory.'Summary/report.html', 'Summary report HTML');

#< soap test ># TODO

done_testing();
exit;

