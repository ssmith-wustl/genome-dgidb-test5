package Genome::GeneNameReport::Set::View::Status::Xml;

use strict;
use warnings;
use Genome;
use Data::Dumper;
use XML::LibXML;

class Genome::GeneNameReport::Set::View::Status::Xml {
    is => 'Genome::View::Status::Xml',
    has_constant => [
        default_aspects => {
            is => 'ARRAY',
            value => [
                {
                    name => 'members',
                    perspective => 'default',
                    toolkit => 'xml',
                    subject_class_name => 'Genome::GeneNameReport',
                    aspects => [
                        'id',
                        'name',
                        'nomenclature',
                        'source_db_name',
                        'source_db_version',
                    ],
                },
                'name',
            ],
        },
    ],
};

1;
