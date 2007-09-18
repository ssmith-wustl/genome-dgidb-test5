package Crossmatch::Reader;

use strict;
use warnings;

use base 'Finfo::Reader';

use Crossmatch::Alignment;
use Crossmatch::DiscrepancyReader;
use Data::Dumper;
use IO::String;

my %header :name(_header:p) :type(string);

sub _return_class
{
    return 'Crossmatch::Alignment';
}

sub header
{
    return shift->_header;
}

sub START
{
    my $self = shift;

    my ($line, $prev_pos, $header);
    while ( my $line = $self->_getline )
    {
        $prev_pos = $self->io->tell;
        $line = $self->_getline;
        last if $self->_line_is_an_alignment_line($line);
        $header .= $line;
    }

    $self->io->seek($prev_pos, 0);

    $self->_header($header);

    return 1;
}

sub _next
{
    my $self = shift;

    my $alignment;
    my $discrep_io = IO::String->new();
    my $num_of_discreps = 0;
    while ( 1 )
    {
        my $prev_pos = $self->io->tell;
        my $line = $self->_getline;
        last unless $line;
        $line =~ s/^\s+//;
        last if $line eq '';
        if ( $self->_line_is_an_alignment_line($line) )
        {
            chomp $line;
            if ( $alignment )
            {
                $self->io->seek($prev_pos, 0);
                last;
            }
            $alignment = $self->_create_alignment_ref_from_line($line);
            next;
        }
        $discrep_io->print($line);
        $num_of_discreps++;
    }

    return unless $alignment;
    
    if ( $num_of_discreps )
    {
        $discrep_io->seek(0, 0);
        my $discrep_reader = Crossmatch::DiscrepancyReader->new
        (
            io => $discrep_io,
            return_as_objs => $self->return_as_objs,
        )
            or return;
        my @discrepancies = $discrep_reader->all
            or return;
        $alignment->{discrepancies} = \@discrepancies;
    }

    #print Dumper($alignment);

    return $alignment;
}

# Here's some alignments.  They may not have the 'ALIGMENT' at the
# beginning, a star(*) at the end or a 'C' in the middle.  Fun, huh?
# ALIGNMENT    89  8.33 0.00 0.00  Contig169        1   120 (49)  C AluSx_SINE/Alu   (171)   131    12 *
# ALIGNMENT  1159  0.08 0.08 0.00  Contig958        1  1193 (0)    Contig11       15  1208 (8)

sub _line_is_an_alignment_line
{
    my ($self, $line) = @_;

    $line =~ s/^\s+//;

    return $line =~/^(ALIGNMENT)?\s*\d+\s+\d+\.\d+\s+\d+\.\d+\s+/;
}

sub _create_alignment_ref_from_line : PRIVATE
{
    my ($self, $line) = @_;

    my @tokens = split(/\s+/, $line);
    pop @tokens if $tokens[-1] eq '*';

    my %alignment =
    (
        sw_score => $tokens[0],
        per_sub => $tokens[1],
        per_del => $tokens[2],
        per_ins => $tokens[3],
        query_name => $tokens[4],
        query_start => $tokens[5],
        query_stop => $tokens[6],
    );
    
    unless ( defined $tokens[7] ) 
    {
        print Dumper($line);
    }
    
    $tokens[7] =~ s/[\(\)]//g;
    $alignment{bases_after}=$tokens[7];

    $alignment{subject_name} = $tokens[-4];
    if ($tokens[8] =~ /^C$/)
    {
        $tokens[-3] =~ s/[\(\)]//g;
        $alignment{bases_before} = $tokens[-3];
        
        $alignment{subject_start} = $tokens[-2];
        $alignment{subject_stop} = $tokens[-1];
    }
    else
    {
        $alignment{subject_start} = $tokens[-3];
        $alignment{subject_stop} = $tokens[-2];

        $tokens[-1] =~ s/[\(\)]//g;
        $alignment{bases_before} = $tokens[-1];
    }

    return \%alignment;
}

1;

=pod

=head1 Name

 Crossmatch::Reader

=head1 Description

 Crossmatch output file reader.

=head1 Usage

 use Crossmatch::Reader

 my $reader = Crossmatch::Reader->new
 (
     io => 'cm.out', # required - file or IO::* object
     return as_objedcts => 1, # optional - return alignments as hashrefs or Crossmatch::Alignment objects
 )
    or die;
 
 my @alignments = $reader->all;

=head1 Methods

=head2 next

 my $alignment = $reader->next;

=over

=item I<Synopsis>   Parses, creates and returns a alignment from the io

=item I<Params>     none

=item I<Returns>    alignment (hashref/object, scalar)

=back

=head2 all

 my $alignment = $reader->all;

=over

=item I<Synopsis>   Parses, create and returns all of the alignments from the io

=item I<Params>     none

=item I<Returns>    all alignment (hashrefs/objects, array)

=back

=head1 See Also

=over

=item Crossmatch dir

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
