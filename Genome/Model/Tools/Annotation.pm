package Genome::Model::Tools::Annotation;

use strict;
use warnings;

use Genome;     

class Genome::Model::Tools::Annotation {
    is => 'Command',
};

sub sub_command_sort_position { 15 }

sub help_brief {
    "annotation tools"
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
genome-model tools annotation ...    
EOS
}

1;

