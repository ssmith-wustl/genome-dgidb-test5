package Genome::Vocabulary;

use warnings;
use strict;

use UR;

UR::Object::Class->define(
    class_name => 'Genome::Vocabulary',
    is => ['UR::Vocabulary'],
    english_name => 'genome vocabulary',
);


1;
