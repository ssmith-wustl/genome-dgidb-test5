package Genome::Model::Command::Build::DeNovoAssembly::Preprocess;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::DeNovoAssembly::Preprocess {
    is_abstract => 1,
    is => [qw/ Genome::Model::Event /],
};

sub command_subclassing_model_property {
    return 'assembler_name';
}

sub execute {
    my $self = shift;

    return 1;
}

1;

#$HeadURL$
#$Id$
