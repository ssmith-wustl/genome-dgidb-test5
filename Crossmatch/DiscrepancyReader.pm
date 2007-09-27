package Alignment::Crossmatch::DiscrepancyReader;

use strict;
use warnings;

use base 'Finfo::Reader';

use Alignment::Crossmatch::DiscrepancyList;
use Alignment::Crossmatch::DiscrepancyHistogram;
use Data::Dumper;

my %_string :name(_string:p) :type(string);
my %_type :name(_type:p) :type(in_list) :options([qw/ list table /]) :default('list');

sub START
{
    my $self = shift;

    my $line;
    while ( $line = $self->_getline )
    {
        last if $line =~ /\w\d/;
    }

    $line =~ /Discrep(ancy)?\s+(\w+)/;
    my $type = $2;

    unless ( $type )
    {
        $self->_reset; # if no type, it's probably a list
    }
    elsif ( $type eq 'histogram' )
    {
        $self->_type('table');
        $self->_getline; # this line is a header
    }
    elsif ( $type eq 'list' )
    {
        # do nothing, current line is a header
    }
    else # unsupported type
    {
        $self->_fatal_msg("Unsupported discrepancy type ($type)");
        return;
    }

    return 1;
}

sub _return_class
{
    my $self = shift;

    return 'Alignment::Crossmatch::Discrepancy' . ucfirst $self->_type;
}

# Discrepancy histogram
# Qual algn  cum    rcum    (%)    unalgn X    N  sub del ins  total (%)   cum  rcum (%)
# 15    120    120    120 (100.00)    11  0    0  10   0   0    10 (8.33)   10   10 (8.33)
#
# Discrep list
# DISCREPANCY   D-3   160  T(-1)    240  atccctTtgctcc
# DISCREPANCY   S     335  C(-1)     63  tttgaaCggcact
# DISCREPANCY   I-2    28  TT(0)    425  ggcacgTTgttggc
# DISCREPANCY   D     588  A(-1)    987  aaatggAtataga
# 
# or
# 
# S   1459565  C(15)  206217  tccaggCtatttt
# D   1470261  T(15)  216914  cggcctTcatatt
# I   1474631  A(15)  221283  ttgtcaAtgaaac
sub _next
{
    my $self = shift;

    my $line = $self->_getline;

    return if not defined $line or $line eq '';

    chomp $line;

    my $method = '_parse_' . $self->_type;

    return $self->$method($line);
}

sub _parse_histogram
{
    my ($self, $line) = @_;
    
    my @tokens = split(/\s+/, $line);
    my %discrep = ( type => 'histogram' );
    @discrep {qw/
        quality align align_cum align_rcum align_per unalign X
        N sub del ins discrep_total discrep_per discrep_cum discrep_rcum
        /} = @tokens;

    return \%discrep;
}

sub _parse_list
{
    # DISCREPANCY   D-3   160  T(-1)    240  atccctTtgctcc
    # /^DISCREPANCY\s+([DSI])-?\d\s+(\d+)\s+(\w+)\(\-?\d+\)\s+(\d+)\s+(\w+)$/
    #
    # S   1459565  C(15)  206217  tccaggCtatttt
    # D-2   105  C(15)   7443  ctgctgCtgtatg
    my ($self, $line) = @_;

    $line =~ s/DISCREPANCY//;
    $line =~ s/^\s+//;

    my @tokens = split(/\s+/, $line);
    $self->fatal_msg("Invalid discrepancy line:\n$line")
        and return unless @tokens == 5;

    my ($mut, $num) = split /\-/, $tokens[0];
    $num = 1 unless defined $num;

    my ($base, $bases_in_seq) = split(/\(/, $tokens[2]);

    return 
    {
        mutation => $mut,
        number => $num, 
        query_pos => $tokens[1],
        base => $base,
        subject_pos => $tokens[3],
        sequence => $tokens[4]
    };
}

1;

=pod

=head1 Name

Alignment::Crossmatch::DiscrepancyStringParser

=head1 Description

Parses a discrepancy string from a crossmatch output.  Mainly a helper object for Alignment::Crossmatch::Reader.

=head1 Usage

 use Alignment::Crossmatch::DiscrepancyReader

 my $reader = Alignment::Crossmatch::DiscrepancyStringParser->new
 (
    io => $discrep_io, # required
    return_as_objs => 1, # optional
 )
    or die;

 my @discrepancies = $reader->all
    or die;

=head1 Methods

=head2 next

 my $discrep = $reader->next;

=over

=item I<Synopsis>   Parses, creates adn returns a discrepancy from the io

=item I<Params>     none

=item I<Returns>    discrepancy (hashref/object, scalar)

=back

=head2 all

 my $discrep = $reader->all;

=over

=item I<Synopsis>   Parses, create and returns all of the discrepancies from the io

=item I<Params>     none

=item I<Returns>    all discrepancies (hashrefs/objects, array)

=back

=head1 See Also

=over

=item cross_match

=item Alignment::Crossmatch::Discrepancy

=item Alignment::Crossmatch directory

=item Finfo::Reader

=back

=head1 Disclaimer

Copyright (C) 2006-7 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> <ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
