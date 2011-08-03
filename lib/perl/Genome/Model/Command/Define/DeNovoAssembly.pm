package Genome::Model::Command::Define::DeNovoAssembly;

use strict;
use warnings;

use Genome;

require Carp;
use Regexp::Common;

class Genome::Model::Command::Define::DeNovoAssembly {
    is => 'Genome::Model::Command::Define::Helper',
    has => [
        center_name => {
            is => 'Text',
            valid_values => [qw/ WUGC LANL Baylor /],
            doc => 'Center name.'
        },
    ]
};

sub type_specific_parameters_for_create {
    my $self = shift;
    return ( center_name => $self->center_name );
}

sub listed_params {
    my $self = shift;
    return ($self->SUPER::listed_params, 'center_name');
}

1;

