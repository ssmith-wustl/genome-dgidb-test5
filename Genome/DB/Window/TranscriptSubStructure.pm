package Genome::DB::Window::TranscriptSubStructure;

use strict;
use warnings;

use base 'Genome::DB::Window';

use Data::Dumper;

my %sub_structs :name(_sub_structures:p) :ds(aryref) :empty_ok(1);
my %cds_exons :name(_cds_exons:p) :ds(aryref) :empty_ok(1);

sub START
{
    my $self = shift;

    my $iterator = $self->iterator;
    my (@sub_structures, @cds_exons);
    while ( my $sub_structure = $iterator->next )
    {
        push @sub_structures, $sub_structure;
        push @cds_exons, $sub_structure if $sub_structure->structure_type eq 'cds_exon';
    }

    $iterator->reset;
    
    $self->_sub_structures(\@sub_structures);
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

sub sub_structures
{
    my $self = shift;

    return @{ $self->_objects };
}

sub sub_structures_flanking_main_structure
{
    my $self = shift;

    my $sub_structures = $self->_sub_structures;
    my $main_structure_ary_index = $self->_iterator_position - 1;

    return 
    ( 
        $sub_structures->[ $main_structure_ary_index - 1 ], 
        $sub_structures->[ $main_structure_ary_index + 1 ],
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

sub cds_exon_length_past_main_structure
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
        @cds_exons = reverse @cds_exons;
        my $structure_start = $main_structure->structure_start;
        $exon_is_past_main = sub
        {
            return $_[0]->structure_stop < $structure_start;
        }
    }

    my $length;
    foreach my $cds_exon ( @cds_exons )
    {
        #next if $cds_exon->transcript_structure_id eq $main_structure->transcript_structure_id;
        next if $exon_is_past_main->($cds_exon);
        $length += $cds_exon->structure_stop - $cds_exon->structure_start + 1;
    }

       $length -= $main_structure->structure_stop - $main_structure->structure_start + 1 if $main_structure->structure_type eq 'cds_exon';

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

