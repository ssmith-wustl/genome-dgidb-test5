package Genome::Sample::View::Solr::Xml;

use strict;
use warnings;

use Genome;

class Genome::Sample::View::Solr::Xml {
    is => 'Genome::View::Solr::Xml',
    has_constant => [
        type => {
            is => 'Text',
            default => 'sample'
        },
        default_aspects => {
            is => 'ARRAY',
            default => [
                {
                    name => 'extraction_label',
                    position => 'content',
                },
                {
                    name => 'extraction_type',
                    position => 'content',
                },
                {
                    name => 'extraction_desc',
                    position => 'content',
                },
                {
                    name => 'cell_type',
                    position => 'content',
                },
                {
                    name => 'tissue_label',
                    position => 'content',
                },
                {
                    name => 'tissue_desc',
                    position => 'content',
                },
                {
                    name => 'organ_name',
                    position => 'content',
                }
            ],
        }
    ]
};

1;
