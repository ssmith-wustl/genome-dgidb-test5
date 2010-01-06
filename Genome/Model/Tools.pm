
package Genome::Model::Tools;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools {
    is => ['Command'],
    english_name => 'genome model tools',
};

sub command_name {
    'gmt' 
}

sub help_brief {
    "bioinformatics tools for genomics"
}


1;
