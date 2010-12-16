package Genome::Model::Event::Build::DeNovoAssembly::Assemble;

use strict;
use warnings;

use Genome;

class Genome::Model::Event::Build::DeNovoAssembly::Assemble {
    is => 'Genome::Model::Event::Build::DeNovoAssembly',
};

sub bsub_rusage {
    my $self = shift;

    # FIXME
    my $method = $self->processing_profile->assembler_name.'_bsub_rusage';
    if ( $self->processing_profile->can( $method ) ) {
        my $usage = $self->processing_profile->$method;
        return $usage;
    }
    $self->status_message( "bsub rusage not set for ".$self->processing_profile->assembler_name );
    return;
}

sub execute {
    my $self = shift;

    return $self->processing_profile->assemble_build( $self->build );
}

1;

