#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More tests => 5;

BEGIN {
    use_ok('Genome::ProcessingProfile::Command::List');
}

# GOOD
# Create a pp to list
my $pp = Genome::ProcessingProfile::MetaGenomicComposition->create(
    name => 'test meta genomic composition',
    sequencing_platform => 'sanger',
    assembler => 'phredphrap',
    sequencing_center => 'gsc',
    assembly_size => 1300,
);
ok($pp, "Created processing profile to test renaming");
die unless $pp; # can't proceed

my $lister = Genome::ProcessingProfile::Command::List->create(filter => 'name=test meta genomic composition');
ok($lister, 'Created the lister');
isa_ok($lister, 'Genome::ProcessingProfile::Command::List');
ok($lister->execute, 'Executed the lister, look at the listing!!');

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

