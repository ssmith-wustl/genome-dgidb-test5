package Genome::Utility::IO::StdoutRefWriter;

use strict;
use warnings;

require Carp;
use Data::Dumper 'Dumper';
require Storable;

my $id = 0;
sub create {
    my $class = shift;
    return bless { id => ++$id }, $class;
}

sub id {
    return $_[0]->{id};
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

sub flush { return 1; }

1;

