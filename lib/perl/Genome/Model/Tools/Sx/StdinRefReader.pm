package Genome::Model::Tools::Sx::StdinRefReader;

use strict;
use warnings;

require Storable;

class Genome::Model::Tools::Sx::StdinRefReader { 
    has => [ 
        name => { is => 'Text', is_optional => 1, },
    ],
}; 

sub read {
    my $self = shift;

    my $ref = eval { Storable::fd_retrieve(*STDIN) };

    return $ref;
}

1;

