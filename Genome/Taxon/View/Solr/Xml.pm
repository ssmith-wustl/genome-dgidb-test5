package Genome::Taxon::View::Solr::Xml;

use strict;
use warnings;

use Genome;

class Genome::Taxon::View::Solr::Xml {
    is => 'Genome::View::Solr::Xml',
    has_constant => [
        type => {
            is => 'Text',
            default => 'taxon'
        },
        default_aspects => {
            is => 'ARRAY',
            default => [
                {
                    name => 'domain',
                    position => 'content',
                },
                {
                    name => 'species_name',
                    position => 'content',
                },
                {
                    name => 'strain_name',
                    position => 'content',
                },
                {
                    name => 'species_latin_name',
                    position => 'content',
                },
                {
                    name => 'ncbi_taxon_id',
                    position => 'content',
                },
            ],
        }
    ]
};

1;
