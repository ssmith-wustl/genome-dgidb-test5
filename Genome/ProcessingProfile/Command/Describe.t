#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More tests => 8;

BEGIN {
    use_ok('Genome::ProcessingProfile::Command::Describe');
}

# GOOD
# Create a pp to describe
my $pp = Genome::ProcessingProfile::MetaGenomicComposition->create(
    name => 'test meta genomic composition',
    sequencing_platform => 'sanger',
    assembler => 'phredphrap',
    sequencing_center => 'gsc',
    assembly_size => 1300,
);
ok($pp, "Created processing profile to test renaming");
die unless $pp; # can't proceed

my $describer = Genome::ProcessingProfile::Command::Describe->create(processing_profile_id => $pp->id);
ok($describer, 'Created the describer');
isa_ok($describer, 'Genome::ProcessingProfile::Command::Describe');
ok($describer->execute, 'Executed the describer');

my $bad_describer = Genome::ProcessingProfile::Command::Describe->create();
ok($bad_describer, 'Created the describer w/o processing profile id');
isa_ok($bad_describer, 'Genome::ProcessingProfile::Command::Describe');
ok(!$bad_describer->execute, 'Execute failed as expected for the describer w/o processing profile id');

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

