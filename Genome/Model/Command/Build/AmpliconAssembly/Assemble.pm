package Genome::Model::Command::Build::AmpliconAssembly::Assemble;

use strict;
use warnings;

use Genome;

require Genome::Model::Tools::AmpliconAssembly::Assemble;

class Genome::Model::Command::Build::AmpliconAssembly::Assemble{
    is => 'Genome::Model::Event',
};

sub execute {
    my $self = shift;

    my $assemble = Genome::Model::Tools::AmpliconAssembly::Assemble->create(
        directory => $self->build->data_directory,
        sequencing_center => $self->model->sequencing_center,
    )
        or return;
    $assemble->execute
        or return;

    return 1;
}

1;

#$HeadURL$
#$Id$
