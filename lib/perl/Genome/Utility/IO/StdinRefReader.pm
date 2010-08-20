package Genome::Utility::IO::StdinRefReader;

use strict;
use warnings;

use Data::Dumper 'Dumper';
require Storable;

sub create {
    my ($class, %params) = @_;
    return bless \%params, $class;
}

BEGIN {
    *Genome::Utility::IO::StdinRefReader::next = \&read;
}
sub read {
    my $self = shift;

    my $ref;
    eval { $ref = Storable::fd_retrieve(*STDIN) };

    return $ref;
}

1;

#$HeadURL$
#$Id$
