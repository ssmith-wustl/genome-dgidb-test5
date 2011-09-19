#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More;

# Use
use_ok('Genome::Model::Tools::Sx::Base') or die;

# Quality calculations
is(Genome::Model::Tools::Sx::Base->calculate_average_quality('BBAB<BBBBAB=??#@?8@1(;>A::(4@?--98#########################################'), 13, 'calculate average quality'); 

done_testing();
exit;

