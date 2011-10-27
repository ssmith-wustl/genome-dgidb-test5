package Genome::GeneNameReport::View::Status::Xml;

use strict;
use warnings;
use Genome;
use Data::Dumper;
use XML::LibXML;

class Genome::GeneNameReport::View::Status::Xml {
    is => 'Genome::View::Status::Xml',
    has_constant => [
        default_aspects => {
            is => 'ARRAY',
            value => [
                'id',
                'name',
                'nomenclature',
                'source_db_name',
                'source_db_version',
            ]
        }
    ],
};

1;
