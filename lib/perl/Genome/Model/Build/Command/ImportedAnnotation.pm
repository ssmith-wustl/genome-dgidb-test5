package Genome::Model::Build::Command::ImportedAnnotation;

use strict;
use warnings;

use Genome;

class Genome::Model::Build::Command::ImportedAnnotation {
    is => 'Genome::Command::Base',
    doc => "Work with imported-annotation builds.",
    is_abstract => 1,
};

1;

