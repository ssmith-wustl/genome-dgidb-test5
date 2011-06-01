#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Genome::ProcessingProfile::Test;
use Test::More 'no_plan';

BEGIN {
    use_ok('Genome::ProcessingProfile::Command::Rename');
}

# GOOD
# Create a pp to rename
my $pp = Genome::ProcessingProfile::Test->create_mock_processing_profile('tester');
ok($pp, "Created processing profile to test renaming");
die unless $pp; # can't proceed

my $new_name = 'eddie awesome pp for mgc';
my $renamer = Genome::ProcessingProfile::Command::Rename->create(
    processing_profile_id => $pp->id,
    new_name => $new_name,
);
ok($renamer, 'Created the renamer');
isa_ok($renamer, 'Genome::ProcessingProfile::Command::Rename');
ok($renamer->execute, 'Executed the renamer');
is($pp->name, $new_name, 'Rename successful');

# BAD - expected to fail
ok(1, "Testing the failures");

# invalid id - sanity check that we have a _verify_processing_profile method before executing
my $bad1 = Genome::ProcessingProfile::Command::Rename->create(
    processing_profile_id => -1,
);
ok($bad1, 'Created the renamer w/ invalid id');
isa_ok($bad1, 'Genome::ProcessingProfile::Command::Rename');
ok(!$bad1->execute, 'Execute failed as expected');

# no name
my $bad2 = Genome::ProcessingProfile::Command::Rename->create(
    processing_profile_id => $pp->id,
);
ok($bad2, 'Created the renamer w/o name');
isa_ok($bad2, 'Genome::ProcessingProfile::Command::Rename');
ok(!$bad2->execute, 'Execute failed as expected');

# invalid name
my $bad3 = Genome::ProcessingProfile::Command::Rename->create(
    processing_profile_id => $pp->id,
    new_name => '',
);
ok($bad3, 'Created the renamer w/ invalid name');
isa_ok($bad3, 'Genome::ProcessingProfile::Command::Rename');
ok(!$bad3->execute, 'Execute failed as expected');

# same name
my $bad4 = Genome::ProcessingProfile::Command::Rename->create(
    processing_profile_id => $pp->id,
    new_name => $new_name,
);
ok($bad4, 'Created the renamer w/ same name');
isa_ok($bad4, 'Genome::ProcessingProfile::Command::Rename');
ok(!$bad4->execute, 'Execute failed as expected');

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

