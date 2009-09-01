package Genome::Assembly::Pcap::Map;

use strict;
use warnings;

use base qw(Class::Accessor);

use Bio::Seq::SeqWithQuality;
use Bio::Seq;
use Carp;
use Data::Dumper;
use Genome::Assembly::Pcap::Mapping;

Genome::Assembly::Pcap::Map->mk_accessors
(qw/
    name
    bases
    is_inverted
    /);

sub new
{
    my $class = shift;
    my $self = bless {}, $class;

    my ($name, $bases) = @_;

    confess "$class needs a sequence string.\n" unless defined $bases;

    $self->name($name);
    $self->bases($bases);
    #$self->_map([0]);

    return $self;
}

sub _map
{
    my ($self, $m) = @_;

    $self->{_m} = $m if defined $m;

    return @{ $self->{_m} } if defined $self->{_m};

    return [];
}

#max
sub max
{
    my $self = shift;

    $self->{_max} = length $self->bases unless defined $self->{max};

    return $self->{_max};
}


sub max_unpad
{
    my $self = shift;

    $self->{_max_unpad} = length $self->bases_unpad unless defined $self->{max_unpad};

    return $self->{_max_unpad};
}

#bases
sub bases_unpad
{
    my $self = shift;

    my $bases = $self->bases;
    
    $bases =~ s/\*//g;

    return $bases;
}

sub pos_pad
{
    my $self = shift;

    my %pos;
    my $p = 0;
    my $u = 0;
    foreach my $base ( split("", $self->bases))
    {
        $p++;
        $u++ unless $base eq '*';
        $pos{$u} = $p unless defined $pos{$u};
    }
    
    return \%pos;
}

sub pos_unpad
{
    my $self = shift;

    my %pos;
    my $p = 0;
    my $u = 0;
    foreach my $base ( split("", $self->bases))
    {
        $p++;
        $u++ unless $base eq '*';
        $pos{$p} = $u;
    }

    return \%pos;
}

sub _complement_bases
{
    my $self = shift;

   return $self->bases( join("", reverse( split("", $self->bases) ) ));
}

#other
sub _check
{
    my $self = shift;

    return unless $self->_map;

    return 1;
}

sub edit
{
    my ($self, $start, $stop, $value) = @_;
    
    my @m = $self->_map;
    my $max = $self->max;

    $start = ($start >= 1)
    ? $start
    : 1;

    $stop = ($stop <= $max)
    ? $stop
    : $max;

    $value = (defined $value)
    ? $value
    : 1;

    for (my $i = $start; $i <= $stop; $i++)
    {
        $m[$i] = $value;
    }
     
    $self->_map(\@m);

    return $stop - $start + 1;
}

sub remove_regions_less_than
{
    my ($self, $min) = @_;

    return unless $self->_check;

    my $counter = 0;
    my $pos = $self->pos_unpad;
    foreach my $mapping ( $self->create_mappings )
    {
        next if $pos->{ $mapping->parent_stop } - $pos->{ $mapping->parent_start } + 1 >= $min;

        $self->edit($mapping->parent_start, $mapping->parent_stop, 0);
        $counter++;
    }

    return $counter;
}

sub extend
{
    my ($self, $extend) = @_;

    return unless $self->_check;

    my @new_mappings;
    my $max_unpad = $self->max_unpad;

    foreach my $mapping ( $self->create_mappings_unpad )
    {
        my $start = ( $mapping->parent_start - $extend >= 1 )
        ? $mapping->parent_start - $extend
        : 1;

        my $stop = ( $mapping->parent_stop + $extend <= $max_unpad )
        ? $mapping->parent_stop + $extend
        : $max_unpad;

        push @new_mappings, Genome::Assembly::Pcap::Mapping->new
        (
            parent_name => $mapping->parent_name,
            parent_start => $start,
            parent_stop => $stop,
        );
    }

    my @new_map;
    my $pos = $self->pos_pad;
    foreach my $mapping (@new_mappings)
    {
        for (my $i = $pos->{ $mapping->parent_start }; $i <= $pos->{ $mapping->parent_stop }; $i++)
        {
            $new_map[$i] = 1;
        }
    }
    
    $self->_map(\@new_map);

    return;
}

sub invert
{
    my $self = shift;

    return unless $self->_check;
    
    my @m = $self->_map;

    my $max = $self->max;

    my @new;

    for (my $i = 1; $i <= $max; $i++)
    {
        $new[$i] = 1 if !defined $m[$i];
    }

    my $inv = ($self->is_inverted)
    ? 0
    : 1;

    $self->is_inverted($inv);
    
    $self->_map(\@new);

    return;
}

sub create_mappings
{
    my $self = shift;
    
    return unless $self->_check;
    
    my @m = $self->_map;
    my $max = $self->max;

    my ($start, $stop, @mappings);

    for (my $i = 1; $i <= $max; $i++)
    {
        if (defined $m[$i] and $m[$i] == 1)
        {
            $start = $i unless defined $start;
            $stop = $i if $i == $max;
            next unless defined $start and defined $stop;
        }

        if (!defined $m[$i])
        {
            next unless defined $start;
            $stop = $i - 1;
        }

        if (defined $start and defined $stop)
        {
            push @mappings, Genome::Assembly::Pcap::Mapping->new
            (
                parent_name => $self->name,
                parent_start => $start,
                parent_stop => $stop
            );

            $start = undef;
            $stop = undef;
        }
    }

    return @mappings;
}

sub create_mappings_unpad
{
    my $self = shift;

    my @new_mappings;
    my $pos = $self->pos_unpad;
    foreach my $mapping ( $self->create_mappings )
    {
        push @new_mappings, Genome::Assembly::Pcap::Mapping->new
        (
            parent_name => $mapping->parent_name,
            parent_start => $pos->{ $mapping->parent_start },
            parent_stop => $pos->{ $mapping->parent_stop },
        );
    }
    
    return @new_mappings;
}

sub create_bioseqs
{
    my $self = shift;

    return unless $self->_check;
    
    my $unpad_bases = $self->bases_unpad;
    my %pos = $self->pos_unpad;
    my @bioseqs;
    foreach my $map ($self->create_mappings)
    {
        my $start = $pos{ $map->parent_start };
        my $stop = $pos{ $map->parent_stop };

        my $seq_obj = Bio::Seq->new
        (
            '-id'  => $self->name,
            '-seq' => substr($unpad_bases, $start - 1, $stop - $start),
            '-desc' => "region from: $start to: $stop",
            '-alphabet' => 'dna'
        );

        push @bioseqs, $seq_obj;
    }

    return \@bioseqs if @bioseqs;
    return;
}

sub create_bioseqs_with_qual
{
    my ($self, @quals) = @_;

    return unless @quals;

    return unless $self->_check;
    
    my $unpad_bases = $self->bases_unpad;
    my %pos = $self->pos_unpad;
    my @bioseqs;
    foreach my $map ($self->create_mappings)
    {
        my $start = $pos{ $map->parent_start };
        my $stop = $pos{ $map->parent_stop };

        my $seq_obj = Bio::Seq::SeqWithQuality->new
        (
            '-id'  => $self->name,
            '-seq' => substr($unpad_bases, $start - 1, $stop - $start),
            '-qual' => join(" ", splice(@quals, $start - 1, $stop - $start)),
            '-desc' => "region from: $start to: $stop",
            '-alphabet' => 'dna'
        );

        push @bioseqs, $seq_obj;
    }

    return \@bioseqs if @bioseqs;
    return;
}

sub union
{
    my (@maps) = @_;

    confess "Genome::Assembly::Pcap::Map::union is a class method.\n"
    unless @maps and scalar @maps == grep { ref $_ } @maps;

    my $name = $maps[0]->name;
    my $union;
    foreach my $map (@maps)
    {
        $union = Genome::Assembly::Pcap::Map->new( $name, $map->bases ) unless defined $union;
        foreach my $mapping ($map->create_mappings)
        {
            $union->edit($mapping->parent_start, $mapping->parent_stop);
        }
    }
    return $union;
}

sub intersect
{
    my (@maps) = @_;
    
    confess "Genome::Assembly::Pcap::Map::intersect is a class method.\n"
    unless @maps and scalar @maps == grep { ref $_ } @maps;

    my $init=shift @maps;
    my $intersection = Genome::Assembly::Pcap::Map->new( $init->name, $init->bases );
    my @intersection_map=$init->_map;
    my $size = @intersection_map;
    foreach my $map (@maps)
    {
	my @temp_map = $map->_map;
	for (my $i=0;$i<$size;$i++){
	    $intersection_map[$i]=($intersection_map[$i] && $temp_map[$i]);
	}
    }
    $intersection->_map(\@intersection_map);
    return $intersection;
}
	
	    

1;

=pod

=head1 Name & Constructor

Genome::Assembly::Pcap::Map

 > represents the coverage of a contig.

 my $map = Genome::Assembly::Pcap::Map->new($name, $bases);

 * $name      name of object, string, required
 * $bases     bases to associate with the map, string, required

=head1 Methods

=head2 edit

    my $length = $map->edit($start, $stop);

    > Creates a map region from $start to $stop. Return the length of the region.

=head2 max

    my $max = $map->max;

    > Returns the max(length) of the map.

=head2 max

    my $max_unpad = $map->max_unpad;

    > Returns the unpadded max(length) of the map.

=head2 remove_regions_less_than

    my $int = $map->remove_regions_less_than($size)
    
    > Remove map regions that do not exceed the min $size. Returns number of
       regions removed.
 
=head2 extend

    my $int = $map->extend($unpadded_length);

    > Extends each of the map areas by unpadded length.  Returns number of regions.
 
=head2 invert

    $map->invert;
 
    > Inverts the coverage in the map.

=head2 create_mappings

    my $mappings = $map->create_mappings;
    
    > Converts each of the map areas to a Genome::Assembly::Pcap::Mapping object.

=head2 create_bioseqs

    my $bioseqs = $map->create_bioseqs;
    
    > Converts each of the map areas to a Bio::Seq object.  Return an array ref.
 
=head2 create_bioseqs_with_qual

    my $bioseqs = $map->create_bioseqs_with_qual;
    
    > Converts each of the map areas to a Bio::Seq::WithQuality object.
 
==head2 union(@other_maps)

    my $map = GSC::IO::Assembvly::Map->union(@maps);

    > Combines map objects.  Call as class method.  Returns a new map object.

==head2 intersect(@other_maps)

    my $map = Genome::Assembly::Pcap::Map->intersect(@maps);

    > Intersects map objects. Call as class method. Returns a new map object.
=head1 Disclaimer

 Copyright (C) 2006 Washington University Genome Sequencing Center

 This module is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author

Eddie Belter <ebelter@watson.wustl.edu>

=cut
