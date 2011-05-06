#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More;

use_ok('Genome::Model::Event::Build::MetagenomicComposition16s::PrepareInstrumentData::454') or die;

is(
    Genome::Model::Event::Build::MetagenomicComposition16s::PrepareInstrumentData::454->bsub,
    "-R 'span[hosts=1] select[type=LINUX64]'",
    'bsub',
);

done_testing();
exit;

