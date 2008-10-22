package Genome::Model::Tools::Polyphred;

use Genome;
use strict;
use warnings;

class Genome::Model::Tools::Polyphred {
    is => 'Command',
    doc => "the polyphred base caller tool suite for Sanger DNA sequencing reads"
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

