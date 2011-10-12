package Genome::Data::IO;

use strict;
use warnings;

use Carp;
use Genome::Data::Adaptor;

sub create {
    my ($class, %params) = @_;
    $class = ref($class) || $class;
    my $self = {};
    bless($self, $class);

    my $file = delete $params{file};
    unless ($file) {
        Carp::confess 'No file provided to create method of ' . __PACKAGE__;
    }

    my $format = delete $params{format};
    unless ($format) {
        Carp::confess 'No format provided to create method of ' . __PACKAGE__;
    }

    $self->_init_adaptor($file, $format);
    return $self;
}

sub _init_adaptor {
    my ($self, $file, $format) = @_;
    unless ($self->{_adaptor}) {
        my $class = $self->_infer_adaptor_class_from_format($format);
        my $adaptor = $class->create(
            file => $file,
            mode => $self->access_mode()
        );
        unless ($adaptor) {
            Carp::confess "Could not create adaptor object of class $class!"
        }
        $self->{_adaptor} = $adaptor;
    }
    return $self->{_adaptor};
}

sub _infer_adaptor_class_from_format {
    my ($self, $format) = @_;
    unless ($format) {
        Carp::confess "Not given format, cannot infer adaptor!";
    }

    my $class = 'Genome::Data::Adaptor::' . ucfirst(lc($format));
    unless ($class->isa('Genome::Data::Adaptor')) {
        Carp::confess "Adaptor class $class is not a Genome::Data::Adaptor!";
    }
    return $class;
}

sub data_adaptor {
    my $self = shift;
    return $self->{_adaptor};
}

sub produces {
    my $self = shift;
    return $self->data_adaptor->produces;
}

sub access_mode {
    Carp::confess 'Method access_mode must be implemented in subclasses of ' . __PACKAGE__;
}

1;

