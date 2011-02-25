package Finishing::Assembly::Ace::ResultSet;

use strict;
use warnings;

use Finfo::Std;

my %objects :name(objects:r) :ds(aryref) :access(ro);
my %count :name(_count:p) :isa('int gt 0');
my %pos :name(_position:p) :isa('int gt -1') :default(-1);

sub first 
{
    my $self = shift;
    
    return $self->objects->[0];
}

sub last 
{
    my $self = shift;
    
    return $self->objects->[ ($self->_count - 1) ];
}

sub next
{
    my $self = shift;

    my $objects = $self->objects;
    my $position = $self->_increment_position;
    
    return if $position > ($self->_count - 1);

    return $objects->[$position++];
}

sub all 
{
	my $self = shift;

    ( wantarray ) ? @{ $self->objects } : $self->objects;
}

sub _increment_position : PRIVATE
{
    my $self = shift;

    return $self->_position( $self->position + 1 );
}

sub count
{
    my $self = shift;

    unless ( $self->_count )
    {
        $self->_count( scalar @{ $self->objects } );
    }
    
    return $self->_count;
}

sub reset
{
    my $self = shift;
    
    $self->position(-1);

    return 1;
}

1;

#$HeadURL$
#$Id$
