package Genome::Model::Command::Build::ImportedAnnotation;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::ImportedAnnotation {
    is => 'Genome::Model::Command::Build',
};

sub sub_command_sort_position { 41 }

sub help_brief {
    "Build for imported annotation db (not implemented yet => no op)"
}

sub help_synopsis {
    return <<"EOS"
genome-model build mymodel 
EOS
}

sub help_detail {
    return <<"EOS"
One build of a given imported annotation db
EOS
}

1;
