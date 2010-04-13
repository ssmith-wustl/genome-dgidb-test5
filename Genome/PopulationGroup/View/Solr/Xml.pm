package Genome::PopulationGroup::View::Solr::Xml;

use strict;
use warnings;

use Genome;

class Genome::PopulationGroup::View::Solr::Xml {
    is => 'Genome::View::Solr::Xml',
    has_constant => [
        type => {
            is => 'Text',
            default => 'population_group'
        },
        default_aspects => {
            is => 'ARRAY',
            default => [
                {
                    name => 'description',
                    position => 'content',
                },
                {
                    name => 'members',
                    position => 'content',
                    perspective => 'default',
                    toolkit => 'text',
                    aspects => [ 'name' ]
                }
            ],
        }
    ]
};

1;
