package Genome::ProcessingProfile::View::Solr::Xml;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::View::Solr::Xml {
    is => 'Genome::View::Solr::Xml',
    has_constant => [
        type => {
            is => 'Text',
            default => 'processing_profile'
        },
        default_aspects => {
            is => 'ARRAY',
            default => [
                {
                    name => 'type_name',
                    position => 'content',
                }
            ]
        }
    ]
};

1;
