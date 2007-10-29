package Genome;

use warnings;
use strict;

use above "UR";

UR::Object::Class->define(
    class_name => 'Genome',
    is => ['UR::Namespace'],
    english_name => 'genome',
);

require Genome::Model;

1;
