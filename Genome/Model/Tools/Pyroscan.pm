package Genome::Model::Tools::Pyroscan;

use Genome;
use strict;
use warnings;

class Genome::Model::Tools::Pyroscan {
    is => 'Command',
    doc => "the pyroscan base caller tool suite for DNA pyrosequencing reads"
};

sub help_brief {
    shift->get_class_object->doc;
}

sub help_detail {
    return <<EOS;
TODO: ADD THIS
EOS
}

1;

