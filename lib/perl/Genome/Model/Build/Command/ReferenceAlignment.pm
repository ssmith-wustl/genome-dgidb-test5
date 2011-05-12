package Genome::Model::Build::Command::ReferenceAlignment;

use strict;
use warnings;

use Genome;

class Genome::Model::Build::Command::ReferenceAlignment {
    is => 'Genome::Command::Base',
    doc => "Work with reference-alignment builds.",
    is_abstract => 1,
};

1;

