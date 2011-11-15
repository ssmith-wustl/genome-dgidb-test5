package Genome::Model::Event::Build::MetagenomicComposition16s::RemoveChimeras;

use strict;
use warnings;

use Genome;

class Genome::Model::Event::Build::MetagenomicComposition16s::RemoveChimeras {
    is => 'Genome::Model::Event::Build::MetagenomicComposition16s',
};

sub execute {
    my $self = shift;

    unless ( $self->build->remove_chimeras ) {
        $self->error_message("Failed to remove chimeras for ".$self->build->description);
        return;
    }

    return 1;
}

1;
