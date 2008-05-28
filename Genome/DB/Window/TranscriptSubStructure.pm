package Genome::DB::Window::TranscriptSubStructure;

use strict;
use warnings;

use base 'Genome::DB::Window';

use Data::Dumper;

my %structs :name(_structures:p) :ds(aryref) :empty_ok(1);
my %cds_exons :name(_cds_exons:p) :ds(aryref) :empty_ok(1);

sub START
{
    my $self = shift;

    my $iterator = $self->iterator;
    my (@structures, @cds_exons);
    while ( my $structure = $iterator->next )
    {
        push @structures, $structure;
        push @cds_exons, $structure if $structure->structure_type eq 'cds_exon';
    }

    $iterator->reset;
    
    $self->_structures(\@structures);
    $self->_cds_exons(\@cds_exons);
    
    return 1;
}

sub object_start_method
{
    return 'structure_start';
}

sub object_stop_method
{
    return 'structure_stop';
}

sub structures
{
    my $self = shift;

    return @{ $self->_objects };
}

sub all_structures
{
    my $self = shift;

    return @{ $self->_structures };
}

sub structures_by_type
{
    my ($self, $type) = @_;

    return grep { $_->structure_type eq $type } @{ $self->_structures };
}

sub main_structure
{
    my $self = shift;

    return $self->_objects->[0];
}

sub structures_flanking_main_structure
{
    my $self = shift;

    my $structures = $self->_structures;
    my $main_structure_ary_index = $self->_iterator_position - 1;

    return 
    ( 
        $structures->[ $main_structure_ary_index - 1 ], 
        $structures->[ $main_structure_ary_index + 1 ],
    );
}

#- CDS EXONS -#
sub cds_exon_range
{
    my $self = shift;

    my @cds_exons = @{ $self->_cds_exons }
        or return;

    return ($cds_exons[0]->structure_start, $cds_exons[$#cds_exons]->structure_stop);
}

sub cds_exon_length
{
    my ($self, $position) = @_;

    my $length = 0;
    foreach my $cds_exon ( @{ $self->_cds_exons } )
    {
        $length += $cds_exon->structure_start - $cds_exon->structure_start + 1;
    }

    return $length;
}

sub length_of_cds_exons_past_main_structure
{
    my ($self, $strand) = @_;

    my @cds_exons = @{ $self->_cds_exons }
        or return;

    my $main_structure = $self->_objects->[0];
    $strand = '+1' unless $strand;

    # Make this an anon sub for slight speed increase
    my $exon_is_past_main;
    if ( $strand eq '+1' )
    {
        my $structure_stop = $main_structure->structure_stop;
        $exon_is_past_main = sub
        {
            return $_[0]->structure_start > $structure_stop;
        }
    }
    else
    {
        my $structure_start = $main_structure->structure_start;
        $exon_is_past_main = sub
        {
            return $_[0]->structure_stop < $structure_start;
        }
    }

    my $length = 0;
    foreach my $cds_exon ( @cds_exons )
    {
        #next if $cds_exon->transcript_structure_id eq $main_structure->transcript_structure_id;
        next unless $exon_is_past_main->($cds_exon);
        $length += $cds_exon->structure_stop - $cds_exon->structure_start + 1;
    }

    if ( $main_structure->structure_type eq 'cds_exon' )
    {
        my $main_structure_length = $main_structure->structure_stop - $main_structure->structure_start + 1;
        return 0 if $main_structure_length > $length; # don't return negative length
        $length -= $main_structure_length;
    }

    return $length;
}

sub cds_exon_with_ordinal
{
    my ($self, $ordinal) = @_;

    foreach my $cds_exon ( @{ $self->_cds_exons } )
    {
        next unless $cds_exon->ordinal == $ordinal;
        return $cds_exon;
    }

    return;
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

