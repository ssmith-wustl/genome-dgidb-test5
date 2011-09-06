package Genome::Model::Tools::Lims;
use strict;
use warnings;
use Genome;

class Genome::Model::Tools::Lims {
    is => 'Command::Tree',
    doc => 'all tools which interface directly with TGI LIMS should go here'
};

sub sub_command_sort_position { -1 }

1;

