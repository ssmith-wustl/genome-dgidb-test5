package Genome::Info::VariantPriorities;

#REVIEW fdu
#ok

use strict;
use warnings;

my %variant_priorities_for_annotation =
(
    nonsense                        => 1,
    missense                        => 2,
    splice_site                     => 3,
    splice_region                   => 4,
    nonstop                         => 5,
    cryptic_splice_site             => 6,
	splice_site_del                 => 7,
    splice_site_ins                 => 8,
    splice_region_del               => 9,
    splice_region_ins                 => 10,
    frame_shift_del                  => 11,
    in_frame_del                     => 12,
    frame_shift_ins                  => 13,
    in_frame_ins                     => 14,
    silent                          => 15,
    '5_prime_untranslated_region'   => 16,
    '3_prime_untranslated_region'   => 17,
    intronic                        => 18,
    '5_prime_flanking_region'       => 19,
    '3_prime_flanking_region'       => 20,
    rna                             => 21,
    undefined                       => 22,
    reference                       => 23,
    consensus_error                 => 100
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
