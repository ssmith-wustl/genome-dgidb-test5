package Genome::Model::Command::Build::DeNovoAssembly::Assemble;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::DeNovoAssembly::Assemble {
    is => ['Genome::Model::Event'],
    is_abstract => 1,
};

sub command_subclassing_model_property {
    return 'assembler_name';
}

1;

#$HeadURL$
#$Id$
