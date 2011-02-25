package GSC::IO::Assembly::Ace::CoverageFilter::ByTags;

use strict;
use warnings;

use base qw(GSC::IO::Assembly::Ace::CoverageFilter);

sub eval_contig
{
    my ($self, $contig) = @_;

    my $name = $contig->name;

    $self->create_map($contig);

    my @tags = @{ $contig->tags };

    foreach my $tag (@tags)
    {
        next unless $self->tag_is_ok($tag);
        
        $self->edit_map($name, $tag->start, $tag->stop);
    }

    return;
}

sub tag_is_ok
{
    my ($self, $tag) = @_;

    return unless defined $tag;

    return grep $tag->type =~ /$_/, $self->patterns
}

1;

=pod

=head1 Name

GSC::IO::Assembly::Ace::CoverageFilter::ByTags
 
> Creates a map of each given contig representing the areas covered by
   tags.

   ** Inherits from GSC::IO::Assembly::Ace::CoverageFilter **
   
=head1 Synopsis

my $cf = GSC::IO::Assembly::Ace::CoverageFilter::ByTags->new(\@patterns);
 * patterns: an array ref of tag types to process

foreach my $contig (@contigs)
{
 $cf->eval_contig($contig);
}

my @maps = $cf->all_maps;

do stuff with the map objects...

=head1 Methods

=head2 eval_contig($contig)

 Evaluates the tags in a GSC::IO::Assembly::Contig and creates a contig map.
 
=head1 See Also

Base class -> GSC::IO::Assembly::CoverageFilter

=head1 Disclaimer

 Copyright (C) 2006 Washington University Genome Sequencing Center

 This module is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author

Eddie Belter <ebelter@watson.wustl.edu>

=cut
