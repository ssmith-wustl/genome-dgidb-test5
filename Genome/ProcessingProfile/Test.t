#! /gsc/bin/perl

# THIS TESTS Genome::ProcessingProfile::Test and processing profile MOCKING

use strict;
use warnings;

use above 'Genome';

use Data::Dumper 'Dumper';
use Test::More 'no_plan';

use_ok('Genome::ProcessingProfile::Test');

# ProcessingProfile
my $processing_profile = Genome::ProcessingProfile::Test->create_mock_processing_profile('tester');
ok($processing_profile, 'Created mock processing profile');
my %attrs_and_values = (
    type_name => [qw/ tester /],
    sequencing_platform => [qw/ solexa /],
    params_for_class => [qw/ sequencing_platform /],
    stages => [qw/ assemble /],
    assemble_job_classes => [qw/ Assemble /],
);
for my $attr ( keys %attrs_and_values ) {
    is_deeply([$processing_profile->$attr], $attrs_and_values{$attr}, $attr);
}
    
exit;

=pod

=head1 Tests

=head1 Disclaimer

 Copyright (C) 2009 Washington University Genome Sequencing Center

 This script is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author(s)

 Eddie Belter <ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
