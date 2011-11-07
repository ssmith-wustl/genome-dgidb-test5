package Genome::DrugGeneInteractionReport::Set::View::Status::Xml;

use strict;
use warnings;
use Genome;
use Data::Dumper;
use XML::LibXML;

class Genome::DrugGeneInteractionReport::Set::View::Status::Xml {
    is => 'Genome::View::Status::Xml',
    has_constant => [
        default_aspects => {
            is => 'ARRAY',
            value => [
               {
                    name => 'members',
                    perspective => 'status',
                    toolkit => 'xml',
                    subject_class_name => 'Genome::DrugGeneInteractionReport',
               },
            ]
        }
    ],
};

1;
