package Genome::Model::Tools::DruggableGene;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::DruggableGene {
    is => 'Command',
    has => [ ],
};

sub sub_command_sort_position { 15 }

sub help_brief {
    'Tools for interacting with druggable genes.'
}

sub help_synopsis {
    return <<"EOS"
gmt druggable-gene ...
EOS
}

1;
