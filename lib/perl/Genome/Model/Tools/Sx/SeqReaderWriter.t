#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Test::More;

use_ok('Genome::Model::Tools::Sx::SeqReader') or die;
use_ok('Genome::Model::Tools::Sx::SeqWriter') or die;

done_testing();
exit;

