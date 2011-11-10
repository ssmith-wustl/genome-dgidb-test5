package Genome::DruggableGene::Command::GeneNameInteractionAssociation;

use strict;
use warnings;

use Genome;

class Genome::DruggableGene::Command::GeneNameInteractionAssociation {
    is => 'Command::Tree',
};

sub help_brief {
    "work with gene-name-interaction-associations"
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
 genome druggable-gene gene-name-interaction-association ...
EOS
}

sub help_detail {
    return <<EOS
A collection of commands to interact with gene-name-interaction-associations.
EOS
}
