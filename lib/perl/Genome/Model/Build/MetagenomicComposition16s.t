#! /gsc/bin/perl
#
#
# All methods in the build are tested in the subclasses - only use_ok here
#
#
#

use strict;
use warnings;

use above 'Genome';

use Test::More tests => 1;

use_ok('Genome::Model::Build::MetagenomicComposition16s');

exit;

