package Alignment::Crossmatch::DiscrepancyHistogram;

use Finfo::Std;

my %quality :name(quality:o) :type(defined);
my %align :name(align:o) :type(defined);
my %align_cum :name(align_cum:o) :type(defined);
my %align_rcum :name(align_rcum:o) :type(defined);
my %align_per :name(align_per:o) :type(defined);
my %unalign :name(unalign:o) :type(defined);
my %x :name(X:o) :type(defined);
my %n :name(N:o) :type(defined);
my %sub :name(sub:o) :type(defined);
my %del :name(del:o) :type(defined);
my %ins :name(ins:o) :type(defined);
my %discrep_total :name(discrep_total:o) :type(defined);
my %discrep_per :name(discrep_per:o) :type(defined);
my %discrep_cum :name(discrep_cum:o) :type(defined);
my %discrep_rcum :name(discrep_rcum:o) :type(defined);

sub type
{
    return 'histogram';
}

1;

=pod

=head1 Name

Alignment::Crossmatch::DiscrepancyHistogram

=head1 Description

An object representing an instance of a crossmatch alignment discrepancy table. 

=head1 Accessors

=over

=item quality

=item align

=item align_cum

=item align_rcum

=item lign_per

=item unalign

=item X

=item N

=item sub

=item del

=item ins

=item discrep_total

=item discrep_per

=item discrep_cum

=item discrep_rcum

=back

=head1 Methods

=head2 type

This discrepancy type is 'histogram', read only.
  
=head1 See Also

=over

=item crossmatch

=item Crossmatch dir

=back

=head1 Author

Edward A. Belter, Jr. <ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
