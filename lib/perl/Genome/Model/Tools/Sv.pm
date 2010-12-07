package Genome::Model::Tools::Sv;

use strict;
use warnings;

use Genome;            

class Genome::Model::Tools::Sv {
    is => 'Command',
    has => [ ],
};

sub sub_command_sort_position { 16 }

sub help_brief {
    'Tools for working with SV files of various kinds.'
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gmt sv ...
EOS
}

sub xhelp_detail {                           
    return <<EOS 
EOS
}

1;

