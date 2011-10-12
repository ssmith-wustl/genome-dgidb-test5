package Genome::Data::IO::Reader;

use strict;
use warnings;

use Genome::Data::IO;
use base 'Genome::Data::IO';

sub access_mode {
    return 'r';
}

sub next {
    my $self = shift;
    my $adaptor = $self->data_adaptor();
    return $adaptor->parse_next_from_file(@_);
}

sub slurp {
    my $self = shift;
    my $adaptor = $self->data_adaptor();
    my @objects;
    while (my $object = $adaptor->parse_next_from_file(@_)) {
        push @objects, $object;
    }
    return @objects;
}

1;

