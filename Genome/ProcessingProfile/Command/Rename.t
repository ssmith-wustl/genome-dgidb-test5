#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More tests => 19;

BEGIN {
    use_ok('Genome::ProcessingProfile::Command::Rename');
}

# GOOD
# Create a pp to rename
my $pp = Genome::ProcessingProfile::MetaGenomicComposition->create(
    name => 'test meta genomic composition',
    sequencing_platform => 'sanger',
    assembler => 'phredphrap',
    sequencing_center => 'gsc',
    assembly_size => 1300,
);
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
# no id
ok(1, "Testing the failures");
my $bad1 = Genome::ProcessingProfile::Command::Rename->create();
ok($bad1, 'Created the renamer w/o id');
isa_ok($bad1, 'Genome::ProcessingProfile::Command::Rename');
ok(!$bad1->execute, 'Could not execute the bad renamer w/o id');
# no name
my $bad2 = Genome::ProcessingProfile::Command::Rename->create(
    processing_profile_id => $pp->id,
);
ok($bad2, 'Created the renamer w/o name');
isa_ok($bad2, 'Genome::ProcessingProfile::Command::Rename');
ok(!$bad2->execute, 'Could not execute the bad renamer w/o name');
# no invalid name
my $bad3 = Genome::ProcessingProfile::Command::Rename->create(
    processing_profile_id => $pp->id,
    new_name => '',
);
ok($bad3, 'Created the renamer w/ invalid name');
isa_ok($bad3, 'Genome::ProcessingProfile::Command::Rename');
ok(!$bad3->execute, 'Could not execute the bad renamer w/ invalid name');
# same name
my $bad4 = Genome::ProcessingProfile::Command::Rename->create(
    processing_profile_id => $pp->id,
    new_name => $new_name,
);
ok($bad4, 'Created the renamer w/ same name');
isa_ok($bad4, 'Genome::ProcessingProfile::Command::Rename');
ok(!$bad4->execute, 'Could not execute the bad renamer w/ same name');

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

