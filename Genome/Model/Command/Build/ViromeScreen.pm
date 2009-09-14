package Genome::Model::Command::Build::ViromeScreen;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::ViromeScreen {
    is => 'Genome::Model::Command::Build',
 };

sub help_brief {
    "Run virome screening on a 454 run"
}

sub help_synopsis {
    return <<"EOS"
genome-model build mymodel
EOS
}

sub help_detail {
    return <<"EOS"
One build of a given assembly model.
EOS
}

1;
