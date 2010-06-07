package Genome::Model::Tools::Assembly::ReadFilter;

use strict;
use warnings;

use Genome;            

class Genome::Model::Tools::Assembly::ReadFilter {
    is => 'Command',
    has => [ ],
};

#sub sub_command_sort_position { 15 }

sub help_brief {
    'Tools for ReadFilter and improvement of assembly data.'
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
genome-model tools assembly ReadFilter ...
EOS
}

sub xhelp_detail {                           
    return <<EOS 
EOS
}

1;

