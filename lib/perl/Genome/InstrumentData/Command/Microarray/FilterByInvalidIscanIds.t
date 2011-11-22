#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More;

use_ok('Genome::InstrumentData::Command::Microarray::FilterByInvalidIscanIds') or die;

my $filter = Genome::InstrumentData::Command::Microarray::FilterByInvalidIscanIds->create();
ok($filter, 'create filter');
ok($filter->filter({id => 'nathan'}), 'did not filter id not in list');
ok(!$filter->filter({id => 'rs1010408'}), 'filter id in list');

done_testing();
exit;

