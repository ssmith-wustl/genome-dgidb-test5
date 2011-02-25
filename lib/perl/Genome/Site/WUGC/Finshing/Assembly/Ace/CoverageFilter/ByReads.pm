package GSC::IO::Assembly::Ace::CoverageFilter::ByReads;

use strict;
use warnings;

use base qw(GSC::IO::Assembly::Ace::CoverageFilter);

sub eval_contig
{
    my ($self, $contig) = @_;

    my $name = $contig->name;
    my $length = $contig->sequence->length;

    $self->create_map($contig);

    if ($contig->isa("GSC::IO::Assembly::Contig"))
    {
        foreach my $read ( values %{ $contig->reads } )
        {
            next unless $self->obj_is_ok($read);

            $self->edit_map
            (
                $name,
                $read->position + $read->align_clip_start - 1,
                $read->position + $read->align_clip_end - 1
            );
        }
    }

    return;
}

sub obj_is_ok
{
    my ($self, $obj) = @_;

    return grep $obj->name =~ /$_/, $self->patterns
}

=pod

=head1 Name

GSC::IO::Assembly::Ace::CoverageFilter::ByReads

> Creates a map of each given contig representing the areas covered by
   reads.  Does not take into account read pair info.

   ** Inherits from GSC::IO::Assembly::Ace::CoverageFilter **

=head1 Synopsis

 my $cf = GSC::IO::Assembly::Ace::CoverageFilter::ByReads->new(\@patterns);

 > The @patterns var is an array of read name patterns.  These will be checked against
    the read name in a pattern match to determine whether or not to process the read.

    grep { $read->name =~ /$_/ } @patterns

 foreach my $contig (@contigs)
 {
   $cf->eval_contig($contig);
 }

 my @maps = $cf->all_maps;

 ...do stuff w/ the maps...

=head1 Methods

=head2 eval_contig($contig)

 Evaluates the reads in a GSC::IO::Assembly::Contig and creates a contig map.

=head1 See Also

 - GSC::IO::Assembly::Ace::CoverageFilter *base class* for map access;
 - GSC::IO::Assembly::Map
 - GSC::IO::Assembly::Mapping 

=head1 Disclaimer

 Copyright (C) 2006 Washington University Genome Sequencing Center

 This script is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author(s)

 Eddie Belter <ebelter@watson.wustl.edu>

=cut

1;

