#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More;

use_ok('Genome::Model::Tools::FastQual::SeqReader') or die;
use_ok('Genome::Model::Tools::FastQual::SeqWriter') or die;

done_testing();
exit;

