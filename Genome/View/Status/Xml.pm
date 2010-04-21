package Genome::View::Status::Xml;

use strict;
use warnings;
use Genome;

class Genome::View::Status::Xml {
    is => 'UR::Object::View::Default::Xml',
    is_abstract => 1,
    has_constant => [
        perspective => {
            value => 'status',
        },
    ],
    doc => 'The base class for creating the XML document representing the full-page status of an object'
};

1;
