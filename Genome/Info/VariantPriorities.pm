package Genome::Info::VariantPriorities;

use strict;
use warnings;

my %variant_priorities_for_annotation =
(
    nonsense => 1,
    missense => 2,
    splice_site => 3,
    splice_region => 4,
    nonstop => 5,
    cryptic_splice_site => 6,
    frameshift_del => 7,
    inframe_del => 8,
    frameshift_ins => 9,
    inframe_ins => 10,
    silent => 11,
    '5_prime_untranslated_region' => 12,
    '3_prime_untranslated_region' => 13,
    intronic => 14,
    '5_prime_flanking_region' => 15,
    '3_prime_flanking_region' => 16,
    undefined => 17,
    reference => 18
);

sub for_annotation
{
    return %variant_priorities_for_annotation;
}

1;

=pod

=head1 Name

ModuleTemplate

=head1 Synopsis

=head1 Usage

=head1 Methods

=head2 

=over

=item I<Synopsis>

=item I<Arguments>

=item I<Returns>

=back

=head1 See Also

=head1 Disclaimer

Copyright (C) 2005 - 2008 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
