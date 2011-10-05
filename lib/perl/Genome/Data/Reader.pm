package Genome::Data::Reader;

use strict;
use warnings;

use Genome::Data::ReaderWriter;
use base 'Genome::Data::ReaderWriter';

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

