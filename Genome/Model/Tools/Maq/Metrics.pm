package Genome::Model::Tools::Maq::Metrics;

use strict;
use warnings;
use Genome;

class Genome::Model::Tools::Maq::Metrics {
    is => 'Command',
    has => [ ],
};

sub sub_command_sort_position { 2 }

sub help_brief { 'tools to work with maq variation metrics' }

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
genome-model tools maq metrics... 
EOS
}

sub help_detail {                           
    return <<EOS 
These are tools to generate additional maq metrics for variation discovery.
More information about the maq suite of tools can be found at http://maq.sourceforege.net.
EOS
}

1;

