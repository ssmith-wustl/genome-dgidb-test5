package Genome::Model::Command::Build::CombineVariants;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::CombineVariants {
    is => 'Genome::Model::Command::Build',
 };

sub sub_command_sort_position { 40 }

sub help_brief {
    "copies any pending input files to a new build and runs variant analysis"
}

sub help_synopsis {
    return <<"EOS"
genome-model build mymodel 
EOS
}

sub help_detail {
    return <<"EOS"
One build of a given PolyphredPolyscan model.
EOS
}


1;
