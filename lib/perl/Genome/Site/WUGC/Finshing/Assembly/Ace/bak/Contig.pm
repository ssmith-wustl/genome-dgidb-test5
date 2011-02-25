package Finishing::Assembly::Ace::Contig;

use strict;
use warnings;

use Finfo::Std;

use Data::Dumper;

my %name :name(_name:r) :isa(code) :access(ro);
my %comp :name(_complemented:r) :isa(code) :access(ro);
my %base_string :name(_base_string:r) :isa(code) :access(ro);
my %length :name(_length:r) :isa(code) :access(ro);
my %qualities :name(_qualities:r) :isa(code) :access(ro);
my %reads :name(_assembled_reads:r) :isa(code) :access(ro);
my %get_read :name(_get_assembled_read:r) :isa(code) :access(ro);
my %read_count :name(_read_count:r) :isa(code) :access(ro);
my %bss :name(_base_segments:r) :isa(code) :access(ro);
my %tags :name(_tags:r) :isa(code) :access(ro);

sub name
{
    my $self = shift;

    return $self->_name->(@_);
}

sub length
{
    return shift->_length->();
}

sub complemented
{
    my $self = shift;

    return $self->_complemented->(@_);
}

sub base_string
{
    my $self = shift;

    return $self->_base_string->(@_);
}

sub qualities
{
    my $self = shift;

    return $self->_qualities->(@_);
}

sub tags
{
    my $self = shift;

    return $self->_tags->(@_);
}

sub read_count
{
    my $self = shift;

    return $self->assembled_reads->count;
}

sub assembled_reads
{
    my $self = shift;

    return $self->_assembled_reads->(@_);
}

sub get_assembled_read
{
    my $self = shift;

    return $self->_get_assembled_read->(@_);
}

sub base_segments
{
    my $self = shift;

    return $self->_base_segments->(@_);
}

sub base_segment_count
{
    my $self = shift;

    return scalar( @{ $self->base_segments } );
}

1;

=pod

=head1 Name

Finishing::Assembly::Ace::Contig.pm

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

