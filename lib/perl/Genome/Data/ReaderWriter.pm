package Genome::Data::ReaderWriter;

use strict;
use warnings;

use Carp;
use Genome::Data::Adaptor;

=head2
Usage: Base class for data readers and writers.
Args : file => File to be written/read
       format => File format (eg, 'fasta')
=cut
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
    my $class = $self->_infer_adaptor_class_from_format($format);
    my $adaptor = $class->create(
        file => $file,
        mode => $self->access_mode()
    );
    unless ($adaptor) {
        Carp::confess "Could not create adaptor object of class $class!"
    }
    $self->{_adaptor} = $adaptor;
    return 1;
}

sub _infer_adaptor_class_from_format {
    my ($self, $format) = @_;
    unless ($format) {
        Carp::confess "Not given format, cannot infer adaptor!";
    }

    my $class = 'Genome::Data::Format' . ucfirst(lc($format));
    unless ($class->isa('Genome::Data::Format')) {
        Carp::confess "Format class $class is not a Genome::Data::Format!";
    }
    return $class;
}

sub data_adaptor {
    my $self = shift;
    return $self->{_adaptor};
}

sub access_mode {
    Carp::confess 'Method access_mode must be implemented in subclasses of ' . __PACKAGE__;
}

1;

