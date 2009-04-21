package Genome::Model::Tools::Assembly::Stats;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Assembly::Stats {
    is => 'Command',
    has => [],
};

sub help_brief {
    'Tools to run assembly stats'
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
genome-model tools assembly stats
EOS
}

sub help_detail {
    return <<EOS
Tools to run assembly stats .. more later	
EOS
}


