#!/usr/bin/env perl

use strict;
use warnings;

use above 'Genome';

use Test::More;

my $class = 'Genome::Model::Build::MetagenomicComposition16s::AmpliconSet';
use_ok($class);

# Valid params
my %params = (
    name => '',
    amplicon_iterator => sub{ return 1; },
    classification_dir => 'dir',
    classification_file => 'file',
    processed_fasta_file => 'file',
    oriented_fasta_file => 'file',
);

# create
my $amplicon_set = $class->create(%params);
ok($amplicon_set, 'Created amplicon set');
is($amplicon_set->name, '', 'Set name');
ok($amplicon_set->next_amplicon, 'Next amplicon');

# FAIL - create w/o reqs
for my $prop ( keys %params ) {
    my $val = delete $params{$prop};
    ok(!$class->create(%params), 'Fail as expected - create w/o '.$prop);
    $params{$prop} = $val;
}

done_testing();

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

