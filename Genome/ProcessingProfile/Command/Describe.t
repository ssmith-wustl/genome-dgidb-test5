#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More tests => 5;

BEGIN {
    use_ok('Genome::ProcessingProfile::Command::Describe');
}

my $describer = Genome::ProcessingProfile::Command::Describe->create(processing_profile_id => 1960767);
ok($describer, 'Created the describer');
isa_ok($describer, 'Genome::ProcessingProfile::Command::Describe');
ok($describer->execute, 'Executed the describer');

my $bad_describer = Genome::ProcessingProfile::Command::Describe->create();
ok(!$bad_describer, 'Could not create the bad describer');

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

