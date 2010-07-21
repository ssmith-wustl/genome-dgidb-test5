package Genome::Capture::Set::View::Status::Xml;

use strict;
use warnings;

use Genome;

class Genome::Capture::Set::View::Status::Xml {
    is => 'Genome::View::Status::Xml',
    has_constant => [
        default_aspects => {
            is => 'ARRAY',
            default => [
                'id',
                'name',
                'status',
                'description',
            ]
        }
    ]
};

1;
