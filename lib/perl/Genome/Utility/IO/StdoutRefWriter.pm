package Genome::Utility::IO::StdoutRefWriter;

use strict;
use warnings;

require Carp;
use Data::Dumper 'Dumper';
require Storable;

sub create {
    my ($class, %params) = @_;
    return bless \%params, $class;
}

sub write {
    my ($self, $ref) = @_;

    unless ( defined $ref ) {
        Carp::confess("Nothing sent to write.");
    }

    unless ( ref($ref) ) {
        Carp::confess("Item sent to write is not a reference: ".Dumper($ref));
    }

    Storable::store_fd($ref, \*STDOUT);

    return 1;
}

1;

#$HeadURL$
#$Id$
