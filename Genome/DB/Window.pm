package Genome::DB::Window;

use strict;
use warnings;

use Finfo::Std;

use Data::Dumper;

my %iterator :name(iterator:r);
my %range :name(range:o) :isa('int gte 0') :default(0);

my %start :name(_start:p) :default(0);
my %stop :name(_stop:p) :default(0);
my %max :name(_max:p);
my %min :name(_min:p);

my %it_pos :name(_iterator_position:p) :default(-1);
my %done :name(_iterator_done:p) :default(0);

my %obj_range_code :name(_object_is_in_range:p) :isa(code);
my %objs :name(_objects:p) :ds(aryref) :empty_ok(1) :default([]);
my %lo_obj :name(_leftover_object:p);

sub START
{
    my $self = shift;

    my $start_method = $self->object_start_method;
    my $stop_method = $self->object_stop_method;
    
    $self->_object_is_in_range
    (
        sub
        {
            my $object = shift;
            return -1 if $object->$stop_method < $self->_min;
            return 1 if $object->$start_method > $self->_max;
            return 0;
        }
    );

    return 1;
}

sub objects
{
    return @{ shift->_objects };
}

sub object_start_method
{
    return 'start';
}

sub object_stop_method
{
    return 'stop';
}

sub max
{
    return shift->_max;
}

sub min
{
    return shift->_min;
}

sub scroll
{
    my ($self, $start, $stop) = @_;

    $self->fatal_msg("Need position to scroll") unless defined $start;

    $stop = $start unless defined $stop;
    
    return @{ $self->_objects } unless $self->_set_ranges($start, $stop);
    
    $self->_remove_objects;
    $self->_add_objects;
    
    return @{ $self->_objects };
}

sub validate_objects
{
    my $self = shift;

    foreach my $object ( @{ $self->_objects } )
    {
        #$self->error_msg("Object not in range") unless $self->_object_is_in_range($object) == 0;
        $self->error_msg("Object not in range") unless $self->_object_is_in_range->($object) == 0;
    }

    return 1;
}

sub _set_ranges
{
    my ($self, $start, $stop) = @_;

    my $current_start = $self->_start;
    my $current_stop = $self->_stop;

    return if $current_start == $start and $current_stop == $stop;

    $self->fatal_msg("Start position to scroll to ($start) is less than the current start position ($current_start)") if  $start < $current_start;

    $self->fatal_msg("Stop position to scroll to ($stop) is less than the current stop position ($current_stop)") if $stop < $current_stop;

    $self->_start($start);
    $self->_stop($stop);
    $self->_max( $start + $self->range );
    $self->_min( $stop - $self->range );

    return 1;
}

sub _remove_objects
{
    my $self = shift;

    my @objects;
    foreach my $object ( @{ $self->_objects } )
    {
        #push @objects, $object if $self->_object_is_in_range($object) eq 0;
        push @objects, $object if $self->_object_is_in_range->($object) eq 0;
    }

    return $self->_objects(\@objects);
}

sub _add_objects
{
    my $self = shift;

    if ( my $leftover_object = $self->_leftover_object )
    {
        #my $in_range = $self->_object_is_in_range($leftover_object); 
        my $in_range = $self->_object_is_in_range->($leftover_object); 

        if ( $in_range == 1 ) # ahead
        {
            # done. return
            return;
        }
        elsif ( $in_range == 0 ) # in range
        {
            # add leftover to objects, contignue
            $self->undef_attribute('_leftover_object');
            push @{ $self->_objects }, $leftover_object;
        }
        # else behind, continue
    }

    while ( 1 )
    {
        my $object = $self->_next_from_iterator
            or return;

        #my $in_range = $self->_object_is_in_range($object);
        my $in_range = $self->_object_is_in_range->($object);
        if ( $in_range == 1 ) # ahead
        {
            # done.  save object and return
            $self->_leftover_object($object);
            return;
        }
        elsif ( $in_range == 0 ) # in range
        {
            # add to objects, continue
            push @{ $self->_objects }, $object;
        }
        # else behind, continue
    }
}

sub _next_from_iterator
{
    my $self = shift;

    return if $self->_iterator_done;
    
    my $object = $self->iterator->next;

    unless ( $object )
    {
        $self->_iterator_done(1);
        return;
    }

    $self->_iterator_position( $self->_iterator_position + 1 );

    return $object;
}

sub __object_is_in_range
{
    my ($self, $object) = @_;
    
    my $stop_method = $self->object_stop_method;
    
    return -1 if $object->$stop_method < $self->_min;
    
    my $start_method = $self->object_start_method;

    return 1 if $object->$start_method > $self->_max;

    return 0;
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

