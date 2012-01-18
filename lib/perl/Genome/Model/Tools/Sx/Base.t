#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More;

# Use
use_ok('Genome::Model::Tools::Sx::Base') or die;

# Quality calculations
is(Genome::Model::Tools::Sx::Base->calculate_average_quality('BBAB<BBBBAB=??#@?8@1(;>A::(4@?--98#########################################'), 13, 'calculate average quality'); 
is(Genome::Model::Tools::Sx::Base->calculate_qualities_over_minumum('BBAB<BBBBAB=??#@?8@1(;>A::(4@?--98#########################################', 20), 27, 'calculate qualities over min'); 

done_testing();
exit;

