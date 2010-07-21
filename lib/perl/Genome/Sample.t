#!/usr/bin/env perl
use strict;
use warnings;

use above "Genome";
use Test::More tests => 6;

use_ok('Genome::Sample');

my $taxon = GSC::Organism::Taxon->get(species_name => 'human');
ok($taxon, 'Get human as organism taxon');

my $s = Genome::Sample->create(
    id               => -123,
    cell_type        => 'primary',
    name             => 'full_name.test',
    common_name      => 'common',
    extraction_label => 'TCGA-1234-232-12',
    extraction_type  => 'test sample',
    extraction_desc  => 'This is a test',
    tissue_desc      => 'normal',
    taxon_id         => $taxon->taxon_id,
);

ok($s, "created a new genome sample data");
isa_ok($s, 'Genome::Sample');
is($s->id, -123, "id is set");

print Data::Dumper::Dumper($s);

my $ok;
eval { $ok = UR::Context->_sync_databases(); };
ok($ok, "saves to the database!") or diag($@);

#UR::Context->commit;
#call $s->delete to delete


