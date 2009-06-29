package Genome::Model::Tools::Assembly::ConvertToPcap;

use strict;
use warnings;

use Genome;            

class Genome::Model::Tools::Assembly::ConvertToPcap {
    is => 'Command',
    has => [ ],
};

sub help_brief {
    'Tools to create pcap-like scaffolded ace files'
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
genome-model tools assembly repair ...
EOS
}

sub xhelp_detail {                           
    return <<EOS
Tools to convert newbler and velvet ace to pcap scaffold format
EOS
}

1;

