package Genome::Capture::Set::View::SearchResult::Xml;

use strict;
use warnings;

use Genome;

class Genome::Capture::Set::View::SearchResult::Xml {
    is => 'Genome::View::SearchResult::Xml',
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
