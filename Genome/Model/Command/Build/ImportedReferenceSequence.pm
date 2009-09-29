package Genome::Model::Command::Build::ImportedReferenceSequence;

use strict;
use warnings;
use Genome;

class Genome::Model::Command::Build::ImportedReferenceSequence {
    is => 'Genome::Model::Command::Build',
 };

sub sub_command_sort_position { 40 }

sub help_brief {
    "Build for imported reference sequence models (not implemented yet => no op)"
}

sub help_synopsis {
    return <<"EOS"
genome-model build mymodel 
EOS
}

sub help_detail {
    return <<"EOS"
One build of a given imported reference sequence
EOS
}


1;
