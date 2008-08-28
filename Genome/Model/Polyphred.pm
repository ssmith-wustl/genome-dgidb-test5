package Genome::Model::Polyphred;

use strict;
use warnings;
use Data::Dumper;

use above "Genome";

class Genome::Model::Polyphred{
    is => 'Genome::Model::Sanger',
};

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    return $self;
}

sub type{
    my $self = shift;
    return "polyphred";
}

1;
