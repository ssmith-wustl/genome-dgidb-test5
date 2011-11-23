package Genome::Data::Mapper;

use strict;
use warnings;
use Genome::Data;
use Carp;

#The creator must specify the from- and to-formats.
#TODO: error checking.  Can they be converted?
sub create {
    my ($class, $from_format, $to_format) = @_;
    if (!defined $from_format || !defined $to_format) {
        Carp::confess __PACKAGE__ ." required from and to formats to be specified";
    }
    my $self = {};
    bless($self, $class);
    $self->{_from_format} = $from_format;
    $self->{_to_format} = $to_format;
#TODO: this next line is stupid.
    $self->{_new_object} = ($self->{_to_format})->create();
    unless ($self->get_new_object) {
        Carp::confess "Could not create new object of type " . $self->{_to_format};
    }

    return $self;
}

#Map a Genome::Data object of one type to another type
sub map {
    Carp::confess "map must be implemented by the child class";
}

sub get_new_object {
    my $self = shift;
    return $self->{_new_object};
}

1;

