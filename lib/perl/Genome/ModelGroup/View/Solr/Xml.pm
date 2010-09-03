package Genome::ModelGroup::View::Solr::Xml;

use strict;
use warnings;

use Genome;

class Genome::ModelGroup::View::Solr::Xml {
    is => 'Genome::View::Solr::Xml',
    has_constant => [
        type => {
            is => 'Text',
            default => 'modelgroup'
        },
        default_aspects => {
            is => 'ARRAY',
            default => [
                {
                    name => 'models',
                    perspective => 'default',
                    toolkit => 'text',
                    aspects => [
                        'id',
                        'name',
                        'subject_name',
                    ],
                    position => 'content',
                },
            ]
        }
    ]
};

1;
