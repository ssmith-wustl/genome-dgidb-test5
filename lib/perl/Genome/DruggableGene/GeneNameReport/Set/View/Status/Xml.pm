package Genome::DruggableGene::GeneNameReport::Set::View::Status::Xml;

use strict;
use warnings;
use Genome;
use Data::Dumper;
use XML::LibXML;

class Genome::DruggableGene::GeneNameReport::Set::View::Status::Xml {
    is => 'Genome::View::Status::Xml',
    has_constant => [
        default_aspects => {
            is => 'ARRAY',
            value => [
                {
                    name => 'members',
                    perspective => 'default',
                    toolkit => 'xml',
                    subject_class_name => 'Genome::DruggableGene::GeneNameReport',
                    aspects => [
                        'id',
                        'name',
                        'nomenclature',
                        'source_db_name',
                        'source_db_version',
                        {
                            name => 'gene_name_report_associations',
                            perspective => 'default',
                            toolkit => 'xml',
                            aspects => [
                              'alternate_name',
                              'nomenclature',
                            ],
                        },
                    ],
                },
                'name',
            ],
        },
    ],
};

1;
