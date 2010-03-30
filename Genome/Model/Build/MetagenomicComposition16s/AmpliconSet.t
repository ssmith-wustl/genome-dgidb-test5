#! /gsc/bin/perl

use strict;
use warnings;

use above 'Genome';

use Test::More 'no_plan';

my $class = 'Genome::Model::Build::MetagenomicComposition16s::AmpliconSet';
use_ok($class);

# FAIL - create w/o amplicon iterator
ok($class->create(), 'Fail as expected - create w/o amplicon iterator');
my $amplicon_set = $class->create(
    amplicon_iterator => sub{ return 1; },
);
ok($amplicon_set, 'Created amplicon set');
ok($amplicon_set->next_amplicon, 'Next amplicon');

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

