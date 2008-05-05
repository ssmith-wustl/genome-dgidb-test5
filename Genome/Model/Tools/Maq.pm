package Genome::Model::Tools::Maq;

use strict;
use warnings;

use above "Genome";                         # >above< ensures YOUR copy is used during development

class Genome::Model::Tools::Maq {
    is => 'Command',
    has => [
        use_version => { is => 'Version', is_optional => 1, default_value => '0.6.3', doc => "Version of maq to use, if not the newest." }
    ],
};

sub sub_command_sort_position { 12 }

sub help_brief {
    "Tools to run maq or work with its output files.",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
genome-model tools maq ...    
EOS
}

sub help_detail {                           
    return <<EOS 
More information about the maq suite of tools can be found at http://maq.sourceforege.net.
EOS
}

1;

