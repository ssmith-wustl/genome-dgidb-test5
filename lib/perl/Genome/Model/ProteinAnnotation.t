#!/usr/bin/env perl
use above 'Genome';
use strict;
use warnings;
use Test::More tests => 3;

Genome::ProcessingProfile::ProteinAnnotation->class;

my $p = Genome::ProcessingProfile::ProteinAnnotation->create(
    name => 'PAP Test 1',
    chunk_size => 10,
    annotation_strategy => 'k-e-g-g-scan union inter-pro-scan',
);
ok($p, "made a processing profile") or die;

my $t = Genome::Taxon->get(name => 'human');
ok($t, "got a taxon") or die;

my $m = $p->add_model(
    name => 'PAP-test-model',
    subject => $t,
    processing_profile => $p
);
ok($m, "created a model");


