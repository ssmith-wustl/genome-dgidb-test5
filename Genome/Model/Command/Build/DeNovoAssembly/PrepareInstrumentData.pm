package Genome::Model::Command::Build::DeNovoAssembly::PrepareInstrumentData;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::DeNovoAssembly::PrepareInstrumentData {
    is_abstract => 1,
    is => [qw/ Genome::Model::Event /],
};

sub command_subclassing_model_property {
    return 'assembler_name';
}

1;

#$HeadURL$
#$Id$
