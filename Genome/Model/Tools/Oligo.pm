package Genome::Model::Tools::Oligo;

use strict;
use warnings;

use Genome;            

class Genome::Model::Tools::Oligo {
    is => 'Command',
    has => [ ],
};

sub sub_command_sort_position { 15 }

sub help_brief {
    'Tools for primers.'
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
genome-model tools oligo ...
EOS
}

sub xhelp_detail {                           
    return <<EOS 
EOS
}

1;

