package Genome::Library::View::Solr::Xml;

use strict;
use warnings;

use Genome;

class Genome::Library::View::Solr::Xml {
    is => 'Genome::View::Solr::Xml',
    has_constant => [
        type => {
            is => 'Text',
            default => 'library'
        },
        default_aspects => {
            is => 'ARRAY',
            default => [
                {
                    name => 'sample_name',
                    position => 'content',
                },
                {
                    name => 'species_name',
                    position => 'content',
                },
            ],
        }
    ]
};

1;
