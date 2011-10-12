package Genome::Data::Adaptor;

use strict;
use warnings;

use Carp;
use IO::File;

=head2 create
Usage: Creates a new object of type Genome::Data::Adaptor. Note that
       this class is an interface and that create should be called
       on a subclass.
Args : file => path to file to be parsed
       mode => access mode, valid values: r, w, a, etc. Defaults to r.
=cut
sub create {
    my ($class, %params) = @_;
    my $self = {};
    bless($self, $class);

    my $file = delete $params{file};
    unless ($file) {
        Carp::confess __PACKAGE__ . " requires a file!";
    }
    $self->file($file);

    my $mode = delete $params{mode};
    $mode ||= 'r';
    $self->access_mode($mode);

    return $self;
}

sub DESTROY {
    my $self = shift;
    $self->{_fh}->close if $self->{_fh};
    return 1;
}

sub file {
    my ($self, $file) = @_;
    if ($file) {
        $self->{_file} = $file;
    }
    return $self->{_file};
}

sub access_mode {
    my ($self, $mode) = @_;
    if ($mode) {
        if ($self->{_mode}) {
            Carp::confess "Can only set mode once, cannot change to $mode!";
        }
        $self->{_mode} = $mode;
    }
    return $self->{_mode};
}

sub _get_fh {
    my $self = shift;
    unless ($self->{_fh}) {
        my $fh = eval { IO::File->new($self->file(), $self->access_mode()) };
        unless ($fh) {
            Carp::confess "Could not create file handle with access mode " 
                . $self->access_mode . " for file " . $self->file();
        }
        $self->{_fh} = $fh;
    }
    return $self->{_fh};
}

# Produces a single Genome::Data object by parsing the next entry in the supplied file. The
# object produced should match what is returned from the produces method.
sub parse_next_from_file {
    my $self = shift;
    Carp::confess "Method parse_next_from_file not implemented in subclass of " . __PACKAGE__;
}

# Given a list of data objects, should write those objects to the output file. The objects
# should also be checked against the return value of the produces method to ensure they're
# of the correct type.
sub write_to_file {
    my ($self, @objects) = @_;
    Carp::confess "Method write_to_file not implemented in subclass of " . __PACKAGE__;
}

# Should return the class of objects that are returned by reading or converted to a file by writing.
# Since all data types inherit from Genome::Data, that's the default, but it should be overridden in
# subclasses to be something more specific. For example, a fasta adaptor should produce
# Genome::Data::Sequence objects.
# TODO It's possible that an adaptor could produce more than one type of object, depending on the user's
# needs. Add this capability.
sub produces {
    return 'Genome::Data';
}

1;

