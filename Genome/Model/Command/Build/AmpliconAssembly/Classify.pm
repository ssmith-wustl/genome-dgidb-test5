package Genome::Model::Command::Build::AmpliconAssembly::Classify;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Command::Build::AmpliconAssembly::Classify {
    is => 'Genome::Model::Event',
};

sub execute {
    my $self = shift;

    my $classify = Genome::Model::Tools::AmpliconAssembly::Classify->create(
        directory => $self->build->data_directory,
    )
        or return;
    $classify->execute
        or return;

    return 1;
}

1;

#$HeadURL$
#$Id$
