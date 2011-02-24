#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More;

note('Tests are in subclasses!');
use_ok('Genome::InstrumentData::Command::Import::GenotypeMicroarray') or die;

done_testing();
exit;

