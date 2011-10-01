package Genome::Data::Sequence;

use strict;
use warnings;

use Carp;

sub create {
    my ($class, %params) = @_;
    my $self = {};
    bless($self, $class);

    $self->sequence_name(delete $params{sequence_name});
    $self->sequence(delete $params{sequence});

    if (%params) {
        Carp::confess "Extra parameters provided to consructor of " . __PACKAGE__;
    }
    return $self;
}

sub sequence_name {
    my ($self, $value) = @_;
    if ($value) {
        $self->{_sequence_name} = $value;
    }
    return $value;
}

sub sequence {
    my ($self, $value) = @_;
    if ($value) {
        $self->{_sequence} = $value;
    }
    return $value;
}

sub length {
    my $self = shift;
    my $sequence = $self->sequence;
    return 0 unless $sequence;
    return length($sequence);
}

1;


