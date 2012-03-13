#!/usr/bin/env perl

BEGIN {
    $ENV{UR_DBI_NO_COMMIT} = 1;
    $ENV{UR_USE_DUMMY_AUTOGENERATED_IDS} = 1;
};

use strict;
use warnings;

use above "Genome";

use Test::More;

use_ok('Genome::Sample') or die;

my $taxon = Genome::Taxon->create(name => '__TEST_TAXON__');
ok($taxon, 'define taxon');

my $source = Genome::Individual->create(name => '__TEST__IND__', taxon => $taxon);
ok($source, 'define source');
print $source->id."\n";

my $sample = Genome::Sample->create(
    name             => 'full_name.test',
    common_name      => 'common',
    extraction_label => 'TCGA-1234-232-12',
    extraction_type  => 'test sample',
    extraction_desc  => 'This is a test',
    cell_type        => 'primary',
    source           => $source,
    tissue_desc      => 'normal',
    is_control       => 0,
    age => 99,
    body_mass_index => 22.4,
);
isa_ok($sample, 'Genome::Sample');
is($sample->subject_type, 'sample_name', 'subject type is organism sample');
is_deeply($sample->taxon, $source->taxon, 'taxon');
is($sample->age, 99, 'age');
is($sample->body_mass_index, 22.4, 'body_mass_index');

ok(eval{ UR::Context->commit; }, 'commit');

done_testing();
exit();

