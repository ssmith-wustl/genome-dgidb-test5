package Genome::DruggableGene::DrugGeneInteractionReport::Set::View::Status::Xml;

use strict;
use warnings;
use Genome;
use Data::Dumper;
use XML::LibXML;

class Genome::DruggableGene::DrugGeneInteractionReport::Set::View::Status::Xml {
    is => 'Genome::View::Status::Xml',
    has_constant => [
        default_aspects => {
            is => 'ARRAY',
            value => [
               {
                    name => 'members',
                    perspective => 'default',
                    toolkit => 'xml',
                    subject_class_name => 'Genome::DruggableGene::DrugGeneInteractionReport',
                    aspects => [
                        'drug_name_report_name',
                        'gene_name_report_name',
                        {
                            name => 'interaction_types',
                            perspective => 'status',
                            toolkit => 'xml',
                            subject_class_name => 'Genome::DruggableGene::DrugGeneInteractionReportAttribute',
                        },
                    ],
               },
            ],
        },
    ],
};

1;
