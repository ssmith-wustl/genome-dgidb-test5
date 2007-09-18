package Crossmatch::Alignment;

use Finfo::Std;

my %subject_name :name(subject_name:r) :type(defined);
my %query_name :name(query_name:r) :type(defined);
my %subject_start  :name(subject_start:r) :type(pos_int);
my %subject_stop  :name(subject_stop:r) :type(pos_int);
my %query_start  :name(query_start:r) :type(pos_int);
my %query_stop  :name(query_stop:r) :type(pos_int);
my %base_before :name(bases_before:r) :type(non_neg_int);
my %base_after :name(bases_after:r) :type(non_neg_int);
my %orientation :name(orientation:r) :type(in_list) :default('U') :options([qw/ U C /]);
my %per_ins :name(per_ins:r) :type(non_neg_real);
my %per_del :name(per_del:r) :type(non_neg_real);
my %persub :name(per_sub:r) :type(non_neg_real);
my %sw_score :name(sw_score:r) :type(pos_int);
my %discrepancies :name(discrepancies:o) :type(aryref) :default([]);

sub query_match_length
{
    my $self = shift;

    return $self->query_stop - $self->query_start + 1;
}

sub subject_match_length
{
    my $self = shift;

    return $self->subject_stop - $self->subject_start + 1;
}

1;

=pod

=head1 Name

Alignment::Crossmatch

=head1 Description

An object representing an instance of a crossmatch alignment.  This object
may be created from the Alignment Reader classes.

=head1 Accessors

=over 

=item subject_name

=item query_name

=item subject_start

=item subject_stop

=item query_start

=item query_stop

=item base_before

=item base_after

=item orientation

=item per_ins

=item per_del

=item persub

=item sw_score

=item discrepancies

=head1 Methods

=head2 query_match_length

    return $self->query_stop - $self->query_start + 1;

=head2 subject_match_length

    return $self->subject_stop - $self->subject_start + 1;

=head1 See Also

=over

=item Crossmatch

=item Alignment classes

=back

=head1 Author

Edward A. Belter, Jr. <ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
