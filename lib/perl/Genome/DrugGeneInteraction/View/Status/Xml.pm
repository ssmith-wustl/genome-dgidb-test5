package Genome::DrugGeneInteraction::View::Status::Xml;

use strict;
use warnings;
use Genome;
use Data::Dumper;
use XML::LibXML;

class Genome::DrugGeneInteraction::View::Status::Xml {
    is => 'Genome::View::Status::Xml',
    has_constant => [
        default_aspects => {
            is => 'ARRAY',
            value => [
               'id',
               'interaction_type',
               {
                    name => 'drug_name',
                    perspective => 'default',
                    toolkit => 'xml',
                    aspects => [
                        'id',
                        'name',
                        'nomenclature',
                        'source_db_name',
                        'source_db_version'
                    ]
               },
               {
                    name => 'gene_name',
                    perspective => 'default',
                    toolkit => 'xml',
                    aspects => [
                        'id',
                        'name',
                        'nomenclature',
                        'source_db_name',
                        'source_db_version'
                    ]
               },
            ]
        }
    ],
};

1;
