package Genome::Model::Tools::MetagenomicClassifier;

use strict;
use warnings;

use Genome;                         # >above< ensures YOUR copy is used during development


class Genome::Model::Tools::MetagenomicClassifier {
    is => 'Command',
};

#sub sub_command_sort_position { 12 }

sub help_brief {
    "Metagenomic classification tools",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
genome-model tools metagenomic-classifier ...    
EOS
}

=cut
sub help_detail {                           
    return <<EOS 
More information about the maq suite of tools can be found at http://maq.sourceforege.net.
EOS
}
=cut

1;

