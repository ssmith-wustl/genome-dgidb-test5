package Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData;

use strict;
use warnings;

use Genome;

class Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData {
    is_abstract => 1,
    is => [qw/ Genome::Model::Event /],
};

sub command_subclassing_model_property {
    return 'assembler_name';
}

1;

#$HeadURL$
#$Id$
