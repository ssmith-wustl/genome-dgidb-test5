#! /gsc/bin/perl

use strict;
use warnings;

use Data::Dumper 'Dumper';
use Test::More 'no_plan';

my $test_class = 'Genome::ProcessingProfile::MicroArrayAffymetrix';
use_ok($test_class) or die;
is_deeply(
    [$test_class->stages], 
    [qw/ micro_array_affymetrix verify_successful_completion /], 
    'Stages',
); 

exit;

=pod

=head1 Tests

=head1 Disclaimer

 Copyright (C) 2006 Washington University Genome Sequencing Center

 This script is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author(s)

 Eddie Belter <ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$

