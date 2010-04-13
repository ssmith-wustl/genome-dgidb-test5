package Genome::Capture::Set::View::Solr::Xml;

use strict;
use warnings;

use Genome;

class Genome::Capture::Set::View::Solr::Xml {
    is => 'Genome::View::Solr::Xml',
    has_constant => [
        type => {
            is => 'Text',
            default => 'capture_set'
        },
        default_aspects => {
            is => 'ARRAY',
            default => [
                {
                    name => 'description',
                    position => 'content',
                }
            ]
        }
    ]
};

1;
