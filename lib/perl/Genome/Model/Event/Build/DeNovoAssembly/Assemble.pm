package Genome::Model::Event::Build::DeNovoAssembly::Assemble;

use strict;
use warnings;

use Genome;

class Genome::Model::Event::Build::DeNovoAssembly::Assemble {
    is => 'Genome::Model::Event::Build::DeNovoAssembly',
};

sub bsub_rusage {
    my $self = shift;

    return $self->processing_profile->bsub_usage;

}

sub execute {
    my $self = shift;

    return $self->processing_profile->assemble_build( $self->build );
}

1;

