#!/usr/bin/env perl
#
# TESTS ARE IN SUBCLASSES
#

use strict;
use warnings;

use above 'Genome';

use Genome::Model::DeNovoAssembly::Test;
use Test::More;

use_ok('Genome::Model::Build::DeNovoAssembly') or die;

done_testing();
exit;

