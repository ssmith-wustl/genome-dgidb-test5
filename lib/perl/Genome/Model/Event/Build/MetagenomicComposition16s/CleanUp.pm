package Genome::Model::Event::Build::MetagenomicComposition16s::CleanUp;

use strict;
use warnings;

use Genome;
      
class Genome::Model::Event::Build::MetagenomicComposition16s::CleanUp {
    is => 'Genome::Model::Event::Build::MetagenomicComposition16s',
};

sub execute {
    my $self = shift;

    unless ( $self->build->clean_up ) {
        $self->error_message('Can\'t clean up after building '.$self->build->description);
        return;
    }

    return 1;
}

1;

#$HeadURL$
#$Id$
