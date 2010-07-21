package Genome::Model::Tools::Polyscan;

use Genome;
use strict;
use warnings;

class Genome::Model::Tools::Polyscan {
    is => 'Command',
    doc => "the polyscan base caller tool suite for Sanger DNA sequencing reads"
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

