
package Genome::Model::Tools;

use strict;
use warnings;

use above "Genome";

class Genome::Model::Tools {
    is => ['Command'],
    english_name => 'genome tools',
};

sub command_name {
    'gt' 
}

sub help_brief {
    "Bioinformatics tools for genomics."
}


1;
