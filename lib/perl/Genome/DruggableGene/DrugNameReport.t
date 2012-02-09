#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';
use Test::More tests => 15;

use_ok('Genome::FeatureList');

my $drug = Genome::DruggableGene::DrugNameReport->get('01314B823E2F11E1846DEABE99417D44');
ok($drug->citation, 'Drug has a citation');
ok($drug->original_data_source_url, 'Drug has an orignal data source url');

#withdrawn
my $withdrawn = Genome::DruggableGene::DrugNameReport->get('01314B823E2F11E1846DEABE99417D44');
ok($withdrawn, 'got a withdrawn drug');
ok($withdrawn->is_withdrawn, 'drug is withdrawn');
my $not_withdrawn = Genome::DruggableGene::DrugNameReport->get('FFFE10DC3E3411E190B8EABE99417D44');
ok($not_withdrawn, 'got a non withdrawn drug');
ok(!$not_withdrawn->is_withdrawn, 'drug is not withdrawn');

#nutraceutical
my $nutra = Genome::DruggableGene::DrugNameReport->get('FFEFE7E43E2C11E1846DEABE99417D44');
ok($nutra, 'got a drug nutraceutical');
ok($nutra->is_nutraceutical, 'drug is nutraceutical');

my $not_nutraceutical = Genome::DruggableGene::DrugNameReport->get('FFFE10DC3E3411E190B8EABE99417D44');
ok($not_nutraceutical, 'got a non nutraceutical drug');
ok(!$not_nutraceutical->is_nutraceutical, 'drug is not nutraceutical');

#approved
my $approved = Genome::DruggableGene::DrugNameReport->get('FFA863BA3E2C11E1846DEABE99417D44');
ok($approved, 'got a drug approved');
ok($approved->is_approved, 'drug is approved');

my $not_approved = Genome::DruggableGene::DrugNameReport->get('FFFE10DC3E3411E190B8EABE99417D44');
ok($not_approved, 'got a non approved drug');
ok(!$not_approved->is_approved, 'drug is not nutraceutical');
