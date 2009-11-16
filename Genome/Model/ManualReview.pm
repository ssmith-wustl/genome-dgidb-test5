package Genome::Model::ManualReview;
#:adukes this was a stubbed in module that was never expanded upon, dump

use strict;
use warnings;

class Genome::Model::ManualReview{
    is => 'Genome::Model',
};

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    die unless $self;

    return $self;
}


# Fill this out to determine what is a valid child model... or just return 1 for now if you like.
# This is called by add_child_model which is a method in Genome::Model::Composite used to add child models to this composite model
sub _is_valid_child {
    my $self = shift;
    my $child_model = shift;

    return 1;
}

1;
