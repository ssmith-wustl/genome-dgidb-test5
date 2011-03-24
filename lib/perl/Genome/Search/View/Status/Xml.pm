
package Genome::Search::View::Status::Xml;

use strict;
use warnings;

class Genome::Search::View::Status::Xml {
    is => 'UR::Object::View::Default::Xml',
    has_constant => [
        perspective => 'status',
        toolkit => 'xml',
        default_aspects => {
            value => ['genome_path', 'ur_path', 'workflow_path']
        }
    ]
};

1;
