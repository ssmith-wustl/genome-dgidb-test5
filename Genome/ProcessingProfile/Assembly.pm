package Genome::ProcessingProfile::Assembly;

use strict;
use warnings;

use above "Genome";

class Genome::ProcessingProfile::Assembly{
    is => 'Genome::ProcessingProfile',
};


sub assembler {
    my $self = shift;
    return $self->get_param_value('assembler');
}

sub create {
    my ($class,%params) = @_;

    my $assembler = delete($params{'assembler'});
    my $self = $class->SUPER::create(%params);
    $self->add_param(name => 'assembler',value => $assembler);
    return $self;
}

1;

