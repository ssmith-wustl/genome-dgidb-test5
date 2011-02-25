package Genome::Site::WUGC::Finishing::Assembly::Project::Namer;

use strict;
use warnings;

use Finfo::Std;

my %base_name :name(base_name:r) 
    :isa(string)
    :clo('base=s')
    :desc('Base name or file for naming');
my %naming_meth :name(naming_method:o) 
    :isa([ 'in_list', __PACKAGE__->valid_naming_methods ]) 
    :default(__PACKAGE__->default_naming_method)
    :clo('naming-method=s')
    :desc('Method for naming: iterate, iterate_and replace(replace pattern \'[]\')');
my %start   :name(start:o) 
    :isa('int non_neg')
    :default(0)
    :clo('start=s')
    :desc('Start number for naming');
my %places  :name(places:o)
    :isa('int non_neg') 
    :clo('places=s') 
    :desc('Number of places for naming');
my %num :name(_num:p) 
    :isa('int gte -1');
my %max :name(_max:p)
    :isa('int pos');

sub valid_naming_methods
{
    return (qw/ iterate iterate_and_replace /); # file /);
}

sub default_naming_method
{
    return ( valid_naming_methods() )[0];
}

sub START
{
    my $self = shift;

    $self->_num( $self->start - 1 );

    if ( defined $self->places )
    {
        # Calculte the maximum # of projects
        my $max = '';
        until (length ($max) == $self->places) { $max .= '9' } 
        $self->_max($max);
    }
    else # no max
    {
        $self->max(0);
    }

    return $self;
}

sub max
{
    return shift->_max;
}

sub next_name
{
    my $self = shift;

    my $method = '_' . $self->naming_method;

    return $self->$method;
}

sub _iterate
{
    my $self = shift;

    return $self->base_name . $self->_next_num;
}

sub _iterate_and_replace
{
    my $self = shift;

    my $num = $self->_next_num
        or return;

    my $name = $self->base_name;

    $name =~ s/\[\]/$num/;
    
    return $name;
}

sub _file
{
    # TODO implement??
    my $self = shift;
    $self->fatal_msg("not implemented");

    my $line = $self->getline;
    chomp $line;
    
    return $line;
}

sub current_num
{
    my $self = shift;

    if (defined $self->places)
    {
        return $self->_add_zeros( $self->_num );
    }
    else
    {
        return $self->_num;
    }   
}

sub change_base_name_and_reset
{
    my ($self, $new_base) = @_;

    return unless $self->change_base_name($new_base);

    return $self->reset_to_start;
}

sub change_base_name
{
    my ($self, $new_base) = @_;

    return $self->base_name($new_base);
}

sub reset_to_start
{
    my $self = shift;

    return $self->_num( $self->start - 1 );
}

sub _next_num
{
    my $self = shift;
    
    my $num = $self->_num;
    $num++;

    $self->error_msg("Namer has run out of names")
        and return if $self->max and $num > $self->max;

    $self->_num($num);

    return $self->_add_zeros( $num ) if $self->places;

    return $num;
}

sub _add_zeros
{
    my ($self, $num) = @_;

    my $places = $self->places;
    
    my $string = '';
    until (length ($string) == $places - length ($num))
    {
        $string .= '0';
    }
    
    return $string . $num;
}

1;

#$HeadURL$
#$Id$

=pod

=cut
