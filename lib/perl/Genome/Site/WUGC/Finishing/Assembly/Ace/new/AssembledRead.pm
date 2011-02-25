package Finishing::Assembly::Ace::AssembledRead;

use strict;
use warnings;

use Data::Dumper;

sub new
{
    my ($class, %p) = @_;

    return bless \%p, $class;
}

sub name
{
    my $self = shift;

    return $self->{_name}->(@_);
}

sub rename
{
    my $self = shift;

    return $self->{_rename}->(@_);
}

sub length
{
    my $self = shift;

    return $self->{_length}->(@_);
}

sub position
{
    my $self = shift;

    return $self->{_position}->(@_);
}

sub complemented
{
    my $self = shift;

    return $self->{_complemented}->(@_);
}

sub base_string
{
    my $self = shift;

    return $self->{_base_string}->(@_);
}

sub qualities
{
    # TODO link to phd info
    return [];
}

sub tags
{
    my $self = shift;

    return $self->{_tags}->(@_);
}

sub qual_clip_start
{
    my $self = shift;

    return $self->{_qual_clip_start}->(@_);
}

sub qual_clip_stop
{
    my $self = shift;

    return $self->{_qual_clip_stop}->(@_);
}

sub align_clip_start
{
    my $self = shift;

    return $self->{_align_clip_start}->(@_);
}

sub align_clip_stop
{
    my $self = shift;

    return $self->{_align_clip_stop}->(@_);
}

sub time
{
    my $self = shift;

    return $self->{_time}->(@_);
}

sub chromat_file
{
    my $self = shift;

    return $self->{_chromat_file}->(@_);
}

sub chem
{
    my $self = shift;

    return $self->{_chem}->(@_);
}

sub dye
{
    my $self = shift;

    return $self->{_dye}->(@_);
}


sub phd_file
{
    my $self = shift;

    return $self->{_phd_file}->(@_);
}

sub info_count
{
    my $self = shift;

    return $self->{_info_count}->(@_);
}

1;

=pod

=head1 Name

Finishing::Assembly::Ace::AssembledRead

=head1 Synopsis

=head1 Usage

=head1 Methods

=head1 See Also

=head1 Disclaimer

Copyright (C) 2007 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$

