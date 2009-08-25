#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More tests => 8;
require Genome::ProcessingProfile::Test;

BEGIN {
    use_ok('Genome::ProcessingProfile::Command::Describe');
}

#< GOOD >#
# Create a pp to describe
my $pp = Genome::ProcessingProfile::Test->create_mock_processing_profile('tester');
;
ok($pp, "Created processing profile to test renaming");
die unless $pp; # can't proceed

my $describer = Genome::ProcessingProfile::Command::Describe->create(processing_profile_id => $pp->id);
ok($describer, 'Created the describer');
isa_ok($describer, 'Genome::ProcessingProfile::Command::Describe');
ok($describer->execute, 'Executed the describer');

#< BAD >#
# invalid id - sanity check that we have a _verify_processing_profile method before executing
my $bad1 = Genome::ProcessingProfile::Command::Describe->create(
    processing_profile_id => -1,
);
ok($bad1, 'Created the describer w/ invalid id');
isa_ok($bad1, 'Genome::ProcessingProfile::Command::Describe');
ok(!$bad1->execute, 'Execute failed as expected');

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

