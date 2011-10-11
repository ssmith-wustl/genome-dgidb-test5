package Genome::Model::Event::Build::MetagenomicComposition16s::DetectChimera;

use strict;
use warnings;

use Genome;

class Genome::Model::Event::Build::MetagenomicComposition16s::DetectChimera {
    is => 'Genome::Model::Event::Build::MetagenomicComposition16s',
};

sub execute {
    my $self = shift;

    $self->error_message("Chimera detector is not ready to run in pipeline");

    return;
}

1;
