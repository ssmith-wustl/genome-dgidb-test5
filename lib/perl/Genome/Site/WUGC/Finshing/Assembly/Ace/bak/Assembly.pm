package Finishing::Assembly::Ace::Assembly;

use strict;
use warnings;

use Finfo::Std;

use Data::Dumper;

my %contig_names :name(_contig_names:r) :isa(code) :access(ro);
my %contig_count :name(_contig_count:r) :isa(code) :access(ro);
my %contigs :name(_contigs:r) :isa(code) :access(ro);
my %get_contig :name(_get_contig:r) :isa(code) :access(ro);
my %assembled_reads :name(_assembled_reads:r) :isa(code) :access(ro);
my %assembled_read_count :name(_assembled_read_count:r) :isa(code) :access(ro);
my %get_assembled_read :name(_get_assembled_read:r) :isa(code) :access(ro);
my %tags :name(_tags:r) :isa(code) :access(ro);

sub contig_count
{
    return shift->contig_count->();
}

sub read_count
{
    return assembled_read_count(@_);
}

sub assembled_read_count
{
    return shift->assembled_read_count->();
}

sub contig_names
{
    return shift->_contig_names->();
}

sub contigs
{
    return shift->_contigs->();
}

sub get_contig
{
    my ($self, $name) = @_;

    return $self->_get_contig->($name);
}

sub assembled_reads
{
    my $self = shift;
    
    $self->_assembled_reads->();
}

sub get_assembled_read
{
    my ($self, $name) = @_;

    return $self->_get_assembled_read->($name);
}

sub tags
{
    my $self = shift;

    return $self->_tags->(@_);
}

1;

=pod

=head1 Name

Finishing::Assembly::Ace::Assembly

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

