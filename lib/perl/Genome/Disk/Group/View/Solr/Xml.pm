package Genome::Disk::Group::View::Solr::Xml;

use strict;
use warnings;

use Genome;

class Genome::Disk::Group::View::Solr::Xml {
    is => 'Genome::View::Solr::Xml',
    has => [
        type => {
            is => 'Text',
            default => 'disk_group'
        },
        default_aspects => {
            is => 'ARRAY',
            default => [
                {
                    name => 'disk_group_name',
                    position => 'title',
                },
                {
                    name => 'group_name',
                    position => 'content',
                }
            ],
        }
    ]
};

# when included in class definition, this fairly regularly
# results in a segfault:
#                {
#                    name => 'user_name',
#                    position => 'content',
#                },

1;
