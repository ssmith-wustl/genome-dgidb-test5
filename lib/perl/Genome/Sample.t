#!/usr/bin/env perl

use strict;
use warnings;

use above "Genome";
use Test::More;

$ENV{UR_DBI_NO_COMMIT} = 1;
$ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;

use_ok('Genome::Sample');

my $taxon = Genome::Taxon->get(species_name => 'human');
ok($taxon, 'Get human as organism taxon');

my $id = -54321;
my $sample = Genome::Sample->get($id);
ok(!$sample, 'sample does not exist');

$sample = Genome::Sample->create(
    id               => $id,
    cell_type        => 'primary',
    name             => 'full_name.test',
    common_name      => 'common',
    extraction_label => 'TCGA-1234-232-12',
    extraction_type  => 'test sample',
    extraction_desc  => 'This is a test',
    tissue_desc      => 'normal',
    taxon_id         => $taxon->taxon_id,
    age => 99,
    body_mass_index => 22.4,
);
ok($sample, "created a new genome sample");
isa_ok($sample, 'Genome::Sample');
is($sample->id, $id, "id is set");
is($sample->subject_type, 'organism sample', 'subject type is organism sample');

print Data::Dumper::Dumper($sample);

my $commit = eval{ UR::Context->commit; };
ok($commit, 'commit');

is($sample->age, 99, 'age');
is($sample->body_mass_index, 22.4, 'body_mass_index');

$sample = Genome::Sample->get($id);

my $file = '/gsc/var/cache/testsuite/data/Genome-Sample/test.xml';
my $size = -s $file;
my $add_file = eval{ $sample->add_file($file); };
diag($@) if $@;
ok($add_file, 'Add file');
my @files = $sample->get_files;
is(@files, 1, 'Got files');
$add_file = eval{ $sample->add_file($file); };
diag($@) if $@;
ok(!$add_file, 'Fail to re-add file');
my $alloc = $sample->disk_allocation;
ok($alloc, 'disk allocation') or die;
is($alloc->kilobytes_requested, $size, 'kb requested');
my $file2 = '/gsc/var/cache/testsuite/data/Genome-Sample/test2.xml';
my $size2 = -s $file2;
$add_file = eval{ $sample->add_file($file2); };
diag($@) if $@;
ok($add_file, 'Add another file');
@files = $sample->get_files;
is(@files, 2, 'Got files');
is($alloc->kilobytes_requested, $size + $size2, 'updated kb requested');
is($sample->data_directory, $alloc->absolute_path, 'sample data directory');

$sample = Genome::Sample->get($id);
ok($sample, 'got new sample');
is($sample->get_organism_taxon, $taxon, 'get_organism_taxon gives expected result');

done_testing();
exit();

