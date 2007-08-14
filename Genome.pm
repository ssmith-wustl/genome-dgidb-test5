
package Genome;

use strict;
use warnings;

use UR;

UR::Object::Class->define(
    class_name => 'Genome',
    is => ['UR::Namespace'],
    english_name => 'genome',
);

# sub get_default_context { "GSC::Context::Production" }

1;

