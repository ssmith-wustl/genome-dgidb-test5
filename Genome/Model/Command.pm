
package Genome::Model::Command;

use strict;
use warnings;

use above "Genome";
use lib '/gsc/scripts/gsc/medseq/lib/'; 

class Genome::Model::Command {
    is => ['Command'],
    english_name => 'genome model command',
};

sub command_name {
    'genome-model' 
}

sub help_brief {
    "Tools for modeling a genome's sequence and features."
}


1;
