package Genome::Model::Polyscan;

use strict;
use warnings;
use Data::Dumper;

use above "Genome";

class Genome::Model::Polyscan{
    is => 'Genome::Model::Sanger',
};

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    return $self;
}

sub type{
    my $self = shift;
    return "polyscan";
}

1;
