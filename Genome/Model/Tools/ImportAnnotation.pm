package Genome::Model::Tools::ImportAnnotation;

use strict;
use warnings;

use Genome;            

class Genome::Model::Tools::ImportAnnotation {
    is => 'Command',
    has => [ ],
};

sub sub_command_sort_position { 15 }

sub help_brief {
    'Tools for importing/downloading various annotation external sets.'
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
genome-model tools import-annotation ...
EOS
}

sub xhelp_detail {                           
    return <<EOS 
EOS
}

1;

# $Id$
