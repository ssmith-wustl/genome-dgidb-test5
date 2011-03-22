package Genome::Site::WUGC::Project::View::Solr::Xml;

use strict;
use warnings;

use Genome;

class Genome::Site::WUGC::Project::View::Solr::Xml {
    is => 'Genome::View::Solr::Xml',
    has => [
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
