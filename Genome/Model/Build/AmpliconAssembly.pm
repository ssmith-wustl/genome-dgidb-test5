package Genome::Model::Build::AmpliconAssembly;

use strict;
use warnings;

use Genome;

class Genome::Model::Build::AmpliconAssembly {
    is => 'Genome::Model::Build',
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    unless ( $self->model->type_name eq 'amplicon assembly' ) {
        $self->error_message( 
            sprintf(
                'Incompatible model type (%s) to build as an amplicon assembly',
                $self->model->type_name,
            )
        );
        $self->delete;
        return;
    }

    return $self;
}


1;

