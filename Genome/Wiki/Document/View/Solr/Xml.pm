package Genome::Wiki::Document::View::Solr::Xml;

use strict;
use warnings;

use Genome;

class Genome::Wiki::Document::View::Solr::Xml {
    is => 'Genome::View::Solr::Xml',
    has_constant => [
        type => {
            is => 'Text',
            default => 'wiki-page'
        },
        default_aspects => {
            is => 'ARRAY',
            default => [
                {
                    name => 'timestamp',
                    position => 'timestamp',
                },
                {
                    name => 'title',
                    position => 'content',
                },
                {
                    name => 'content',
                    position => 'content',
                },
            ],
        }
    ]
};

1;
