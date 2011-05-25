#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Genome::ProcessingProfile::Test;
use Test::More tests => 9;

# This tests the base G:PP:Command functions.
# It uses the 'Rename' module because the base Command class is abstract, and  cannot be directly instantiated

BEGIN {
    use_ok('Genome::ProcessingProfile::Command');
    use_ok('Genome::ProcessingProfile::Command::Rename');
}

#< CREATE A PP TO TEST >#
my $pp = Genome::ProcessingProfile::Test->create_mock_processing_profile('tester');
ok($pp, "Created processing profile to test");
die unless $pp; # can't proceed

# CREATE THE COMMAND >#
my $command = Genome::ProcessingProfile::Command::Rename->create;
ok($command, 'Created the processing profile command');
isa_ok($command, 'Genome::ProcessingProfile::Command');

#< TEST _verify_processing_profile >#
# no id
ok(!$command->_verify_processing_profile, 'Verify failed as expected w/ no processing profile id');
# invalid id - has characters
$command->processing_profile_id('1A1');
ok(!$command->_verify_processing_profile, 'Verify failed as expected w/ invalid id');
# no processing profile for id
$command->processing_profile_id(-1);
ok(!$command->_verify_processing_profile, 'Verify failed as expected w/ id w/o a processing profile');
# valid processing profile id
$command->processing_profile_id( $pp->id );
ok($command->_verify_processing_profile, 'Verify processing profile we just created');

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

