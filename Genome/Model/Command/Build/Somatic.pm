package Genome::Model::Command::Build::Somatic;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::Somatic {
    is => [ 'Genome::Model::Command::Build' ],
 };

sub help_brief {
    "runs the workflow somatic pipeline for a somatic model"
}

sub help_synopsis {
    return <<"EOS"
genome-model build mymodel 
EOS
}

sub help_detail {
    return <<"EOS"
One build of a given somatic model.
EOS
}


1;
