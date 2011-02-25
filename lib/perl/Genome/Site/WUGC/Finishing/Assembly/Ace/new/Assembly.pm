package Genome::Site::WUGC::Finishing::Assembly::Ace::Assembly;

use strict;
use warnings;

use Data::Dumper;

sub new
{
    my ($class, %p) = @_;

    return bless \%p, $class;
}

sub contig_count
{
    return shift->{_contig_count}->();
}

sub read_count
{
    assembled_read_count(@_);
}

sub assembled_read_count
{
    return shift->{_assembled_read_count}->();
}

sub contig_names
{
    return shift->{_contig_names}->();
}

sub contigs
{
    return shift->{_contigs}->();
}

sub get_contig
{
    my $self = shift;

    return $self->{_get_contig}->(@_);
}

sub assembled_reads
{
    my $self = shift;
    
    $self->{_assembled_reads}->();
}

sub get_assembled_read
{
    my $self = shift;

    return $self->{_get_assembled_read}->(@_);
}

sub tags
{
    my $self = shift;

    return $self->{_tags}->(@_);
}

1;

=pod

=head1 Name

Genome::Site::WUGC::Finishing::Assembly::Ace::Assembly

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

