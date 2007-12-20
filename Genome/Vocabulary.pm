package Genome::Vocabulary;

use warnings;
use strict;

use above "Genome";

UR::Object::Type->define(
    class_name => 'Genome::Vocabulary',
    is => ['UR::Vocabulary'],
    english_name => 'genome vocabulary',
);


1;
