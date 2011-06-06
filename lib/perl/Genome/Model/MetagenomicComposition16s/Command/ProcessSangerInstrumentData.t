#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Genome::Model::Test;
use Test::More;

use_ok('Genome::Model::MetagenomicComposition16s::Command::ProcessSangerInstrumentData') or die;
#this is fully tested in Genome::Model::Build::MetagenomicComposition16s::Sanger.t

done_testing();

exit;
