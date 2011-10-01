package Genome::Data::Adaptor;

use strict;
use warnings;

use Carp;

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

sub file {
    my ($self, $file) = @_;
    if ($file) {
        unless (-e $file) {
            Carp::confess "No file found at $file!";
        }
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
        $self->{_mode} = $model;
    }
    return $self->{_mode};
}

sub parse_next_sequence {
    my $self = shift;
    Carp::confess "Method parse_next_sequence not implemented in subclass of " . __PACKAGE__;
}

sub write_sequence {
    my ($self, $sequence) = @_;
    Carp::confess "Method write_sequence not implemented in subclass of " . __PACKAGE__;
}

1;

