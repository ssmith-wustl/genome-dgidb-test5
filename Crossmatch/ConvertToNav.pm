package Crossmatch::ConvertToNav;

use strict;
use warnings;

use Finfo::Std;

use Finishing::Assembly::Consed::Navigation;

# Get reader and writer clo from their classes
my %reader :name(reader:r)
    :type(inherits_from)
    :options([qw/ Crossmatch::Reader /]);
my %writer :name(writer:r)
    :type(inherits_from)
    :options([qw/ Finishing::Assembly::Consed::Navigation::Writer /]);
my %discreps :name(discreps:o)
    :default(1)
    :clo('discreps')
    :desc('Make a navigator for the discrepancies of each cm alignment');
my %reverse_nav :name(reverse_nav:o)
    :default(0)
    :clo('reverse-nav')
    :desc('Make a navigator for subject names, instead of the query names');
my %sub_names :name(subject_names:o)
    :type(non_empty_aryref)
    :clo('subject-names=s@{,}')
    :desc('Match these subject names when going through cm alignments, space separated');
my %query_names :name(query_names:o)
    :type(non_empty_aryref)
    :clo('query-names=s@{,}')
    :desc('Match these query names when going through cm alignments, space separated');

sub execute
{
    my $self = shift;

    my @navs;
    while ( my $alignment = $self->reader->next )
    {
        next unless $self->_alignment_is_ok($alignment);

        push @navs, $self->_create_navigation_for_alignment($alignment)
            or return;

        push @navs, $self->_create_navigations_for_alignments_discrepancies($alignment)
        if $self->discreps;
    }

    unless ( @navs )
    {
        $self->error_msg("No navs were made");
        return;
    }

    $self->writer->write_many(\@navs);

    $self->info_msg
    (
        sprintf
        (
            'Done, wrote %s navigations', 
            scalar @navs,
        )
    );

    return 1;
}

sub _alignment_is_ok : PRIVATE
{
    my ($self, $alignment) = @_;

    if ( $self->subject_names )
    {
        return unless grep 
        {
            $_ eq $alignment->subject_name 
        }
        @{ $self->subject_names };
    }
    
    if ( $self->query_names )
    {
        return unless grep 
        {
            $_ eq $alignment->query_name 
        }
        @{ $self->query_names };
    }
    
    return 1;
}

sub _create_navigation_for_alignment : PRIVATE
{
    my ($self, $alignment) = @_;

    if ( $self->reverse_nav )
    {
        return $self->_create_navigation_for_alignment_reverse($alignment);
    }
    else
    {
        return $self->_create_navigation_for_alignment_regular($alignment);
    }
}

sub _create_navigation_for_alignment_regular : PRIVATE
{
    my ($self, $alignment) = @_;
    
    my ($start, $stop) = ( $alignment->query_start <= $alignment->query_stop )
    ? ( $alignment->query_start, $alignment->query_stop )
    : ( $alignment->query_stop, $alignment->query_start );

    return Finishing::Assembly::Consed::Navigation->new
    (
        contig_name => $alignment->query_name,
        start => $start,
        stop => $stop,
        type => 'CONSENSUS',
        description => sprintf
        (
            'Match %s %d to %d',
            $alignment->subject_name,
            $alignment->subject_start,
            $alignment->subject_stop,
        ),
    );
}

sub _create_navigation_for_alignment_reverse : PRIVATE
{
    my ($self, $alignment) = @_;
    
    my ($start, $stop) = ( $alignment->subject_start <= $alignment->subject_stop )
    ? ( $alignment->subject_start, $alignment->subject_stop )
    : ( $alignment->subject_stop, $alignment->subject_start );

    return Finishing::Assembly::Consed::Navigation->new
    (
        contig_name => $alignment->subject_name,
        start => $start,
        stop => $stop,
        type => 'CONSENSUS',
        description => sprintf
        (
            'Match %s %d to %d (%s)',
            $alignment->query_name,
            $alignment->query_start,
            $alignment->query_stop,
            $alignment->orientation,
        ),
    );
}

sub _create_navigations_for_alignments_discrepancies : PRIVATE
{
    my ($self, $alignment) = @_;

    if ( $self->reverse_nav )
    {
        return $self->_create_navigations_for_alignments_discrepancies_reverse($alignment);
    }
    else
    {
        return $self->_create_navigations_for_alignments_discrepancies_regular($alignment);
    }
}

sub _create_navigations_for_alignments_discrepancies_regular : PRIVATE
{
    my ($self, $alignment) = @_;

    my @navs;
    foreach my $discrep ( @{ $alignment->discrepancies } )
    {
        push @navs, Finishing::Assembly::Consed::Navigation->new
        (
            contig_name => $alignment->query_name,
            start => $discrep->query_pos,
            stop => $discrep->query_pos,
            type => 'CONSENSUS',
            description => sprintf
            (
                '%s here, different base in %s at %s',
                $discrep->base,
                $alignment->subject_name,
                $discrep->subject_pos,
            ), 
        )
            or die;
    }

    return @navs;
}

sub _create_navigations_for_alignments_discrepancies_reverse : PRIVATE
{
    my ($self, $alignment) = @_;

    my @navs;
    foreach my $discrep ( @{ $alignment->discrepancies } )
    {
        push @navs, Finishing::Assembly::Consed::Navigation->new
        (
            contig_name => $alignment->subject_name,
            start => $discrep->subject_pos,
            stop => $discrep->subject_pos,
            type => 'CONSENSUS',
            description => sprintf
            (
                '%s in %s at %s',
                $discrep->base,
                $alignment->query_name,
                $discrep->query_pos
            ),
        )
            or die;
    }

    return sort { $a->start <=> $b->start } @navs;
}

1;
=pod

=head1 Name

Crossmatch::ConvertToNav

=head1 Synopsis

Converts a crossmatch alignemtn to a consed navigation object.

=head1 Usage

 use Crossmatch::ConvertToNav;
 use Crossmatch::Reader;
 use Finishing::Assembly::Consed::Navigation::Writer;

 my $reader = Crossmatch::Reader->new
 (
     io => 'cm.out',
 )
    or die;

 my $writer = Finishing::Assembly::Consed::Navigation::Writer->new
 (
     io => 'cm.nav',
 )
    or die;

 my $converter = Crossmatch::ConvertToNav->new
 (
    # REQUIRED
    reader => $reader,
    writer => $writer,
    # OPTIONAL
    discreps => 1, # Make a navigator for the discrepancies of each cm alignment
    reverse_nav => 1, # Make a navigator for subject names, instead of the query names
    subject_names => [ @sub_names ], # Match these subject names when going through cm alignments (aryref)
    query_names => [ @query_names ], # Match these query names when going through cm alignments (aryref)
 )
    or die;

 $converter->execute
    or die;
 
=head1 Methods

=head2 execute

 $converter->execute
    or die;

=over

=item I<Synopsis>   Converts the cm alignments to consed navs

=item I<Params>     none

=item I<Returns>    true on success, false on failure

=back

=head1 See Also

=over

=item Crossmatch::Reader

=item Finishing::Assembly::Consed::Navigation::Writer

=back

=head1 Disclaimer

Copyright (C) 2007 Washington University Genome Sequencing Center

This module is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

=head1 Author(s)

B<Eddie Belter> I<ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$
