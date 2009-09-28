package Genome::Model::Command::Build::AmpliconAssembly::Orient;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::AmpliconAssembly::Orient {
    is => 'Genome::Model::Event',
};

sub execute {
    my $self = shift;

    my $orient = Genome::Model::Tools::AmpliconAssembly::Orient->create(
        directory => $self->build->data_directory,
    )
        or return;
    $orient->execute
        or return;

    return 1;
}

1;

#$HeadURL$
#$Id$
