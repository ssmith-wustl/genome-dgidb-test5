package Alignment::Crossmatch::DiscrepancyList;

use Finfo::Std;

my %mutation :name(mutation:r) :type(in_list) :options([qw/ S D I /]);
my %base :name(base:r) :type(string);
my %number :name(number:r) :type(pos_int);
my %query_pos :name(query_pos:r) :type(pos_int);
my %subject_pos :name(subject_pos:r) :type(pos_int);
my %sequence :name(sequence:r) :type(string);

sub type 
{
    return 'list';
}

1;

=pod

=head1 Name

Alignment::Crossmatch::DiscrepancyList

=head1 Description

An object representing an instance of a alignment discrepancy list.
These objects are associated with an Alignment::Crossmatch object
and can be accessed by

Alignment::Crossmatch->discrepancies.

DISCREPANCY   D-3   160  T(-1)    240  atccctTtgctcc
DISCREPANCY   S     335  C(-1)     63  tttgaaCggcact
DISCREPANCY   I-2    28  TT(0)    425  ggcacgTTgttggc
DISCREPANCY   D     588  A(-1)    987  aaatggAtataga

 or

S   1459565  C(15)  206217  tccaggCtatttt
D   1470261  T(15)  216914  cggcctTcatatt
I   1474631  A(15)  221283  ttgtcaAtgaaac

=head1 Methods

=head2 type

This discrepancy type is 'list', read only.
  
=head1 Accessors

=head2 mutation

one letter designation of the discrepancy:
 S     substitution
 D     deletion
 I     insertion

=head2 number

number of bases affected by the discrepancy

=head2 query_pos

position in the query

=head2 base

the base(s) effected

=head2 query_pos

position in the query

=head2 subject_pos

position in the subject

=head2 sequence

the sequence with the discrepancy

=head1 See Also

crossmatch, Alignment::Crossmatch and directory

=head1

Copyright (C) 2006-7 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
License for more details.

=head1 Author(s)

Edward A. Belter, Jr. <ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
