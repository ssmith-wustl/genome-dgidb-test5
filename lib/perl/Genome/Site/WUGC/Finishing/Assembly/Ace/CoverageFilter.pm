package Finishing::Assembly::Ace::CoverageFilter;

use strict;
use warnings;

use base qw(Class::Accessor);

use Finishing::Assembly::Map;

Finishing::Assembly::Ace::CoverageFilter->mk_accessors
(qw/
    inverted
    patterns
    /);

sub new
{
    my $class = shift;

    my $self;
    if ( scalar @_ > 1 )
    {
        my %p = @_;
        $self = bless \%p, $class;
    }
    else
    {
        $self = bless {}, $class;
        $self->patterns(shift);
    }

    return $self;
}

sub patterns
{
    my ($self, $patterns) = @_;

    $self->{patterns} = $patterns if $patterns;

    return @{ $self->{patterns} } if $self->{patterns};
}

sub all_maps
{
    my $self = shift;

    return map $self->map_obj($_), $self->names;
}

sub names
{
    my $self = shift;

    return sort {$a cmp $b} keys %{ $self->{maps} } if $self->{maps};
}

sub map_obj
{
    my ($self, $name, $map) = @_;

    $self->{maps}->{$name} = $map if defined $map;
    
    return $self->{maps}->{$name};
}

sub map_max
{
    my ($self, $name) = @_;

    my $map = $self->map_obj($name);

    return $map->max if defined $map;
    return;
}

sub create_map
{
    my ($self, $contig) = @_;

    my $name = $contig->name;

    my $bases = $contig->sequence->padded_base_string;

    my $map = Finishing::Assembly::Map->new($name, $bases);

    return $self->map_obj($name, $map);
}

sub edit_map
{
    my ($self, $name, $start, $stop) = @_;
    
    my $map = $self->map_obj($name);

    $map->edit($start, $stop);

    return;
}

sub edit_map_with_unpad_pos
{
    my ($self, $name, $start, $stop) = @_;
    
    my $map = $self->map_obj($name);

    $map->edit_with_unpad_pos($start, $stop);

    return;
}

sub invert_maps
{
    my $self = shift;

    foreach my $map ($self->all_maps)
    {
        $map->invert;
    }
    
    return;
}
  
sub extend_maps
{
    my ($self, $extend) = @_;
    
    foreach my $map ($self->all_maps)
    {
        $map->extend($extend);
    }

    return;
}

1;

=pod

=head1 Name

Finishing::Assembly::Ace::CoverageFilter
 
 ** BASE CLASS **
 
> Creates a Finishing::Assembly::Map object for each given contig.

=head1 Synopsis

 * See sub classes *

=head1 Methods

=head2 eval_contig($contig)

 Evaluates the tags in a Finishing::Assembly::Contig and creates a contig map.
 
=head2 map_obj($contig_name, $map)

 Gets(include $contig_name only) and  sets(include the $contig_name and $map) the contig $map
  object for $name.
  
=head2 all_maps

 Returns all of the contig map objects.
  
=head2 map_obj($contig_name)
 
 Returns the map for $contig_name.

=head2 invert_maps
 
 Reverses the coverage in the map objects.  
 **Cannot be undone**

=head2 names
 
 Returns a list of names that have maps stored for them.

=head1 See Also

Finishing::Assembly::Map, GSC::IO::Assembly::Mappping  

=head1 Disclaimer

 Copyright (C) 2006 Washington University Genome Sequencing Center

 This module is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author

Eddie Belter <ebelter@watson.wustl.edu>

=cut

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/GSC/IO/Assembly/Ace/CoverageFilter.pm $
#$Id: CoverageFilter.pm 10542 2006-10-17 20:21:54Z ebelter $
