#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Test::More;

diag('TESTS ARE DONE IN BUILD SUBCLASSES');
use_ok('Genome::Model::Event::Build::DeNovoAssembly::Assemble') or die;

done_testing();
exit;

