package Genome::Disk::Volume::View::Solr::Xml;

use strict;
use warnings;

use Genome;

class Genome::Disk::Volume::View::Solr::Xml {
    is => 'Genome::View::Solr::Xml',
    has => [
        type => {
            is => 'Text',
            default => 'disk_volume'
        },
        default_aspects => {
            is => 'ARRAY',
            default => [
                {
                    name => 'mount_path',
                    position => 'title',
                },
                {
                    name => 'disk_group_names',
                    label => 'group',
                    position => 'content',
                }
            ],
        }
    ]
};

1;
