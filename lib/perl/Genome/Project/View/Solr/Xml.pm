package Genome::Project::View::Solr::Xml;

use strict;
use warnings;

use Genome;

class Genome::Project::View::Solr::Xml {
    is => 'Genome::View::Solr::Xml',
    has_constant => [
        type => {
            is => 'Text',
            default => 'project'
        },
        default_aspects => {
            is => 'ARRAY',
            default => [
                {
                    name => 'description',
                    position => 'content',
                },
                {
                    name => 'status',
                    position => 'content',
                }
            ],
        }
    ]
};

1;
