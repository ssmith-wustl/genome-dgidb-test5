package Genome::GeneName::View::Solr::Xml;

use strict;
use warnings;

use Genome;

class Genome::GeneName::View::Solr::Xml {
    is => 'Genome::View::Solr::Xml',
    has => [
        type => {
            is => 'Text',
            default => 'gene-name'
        },
        display_type => {
            is  => 'Text',
            default => 'GeneName',
        },
        display_icon_url => {
            is  => 'Text',
            default => 'genome_gene-name_32',
        },
        display_url0 => {
            is => 'Text',
            calculate_from => ['subject'],
            calculate => q{
                return join ('?id=', '/view/genome/gene-name/status.html', $_->id());
            },
        },
        display_label1 => {
            is  => 'Text',
        },
        display_url1 => {
            is  => 'Text',
        },
        display_label2 => {
            is  => 'Text',
        },
        display_url2 => {
            is  => 'Text',
        },
        display_label3 => {
            is  => 'Text',
        },
        display_url3 => {
            is  => 'Text',
        },
        default_aspects => {
            is => 'ARRAY',
            default => [
                {
                    name => 'name',
                    position => 'title',
                },
                {
                    name => 'nomenclature',
                    position => 'content',
                },
                {
                    name => 'source_db_name',
                    position => 'content',
                },
                {
                    name => 'source_db_version',
                    position => 'content',
                },
                {
                    name => '__display_name__',
                    position => 'display_title',
                },
            ]
        },
    ]
};

1;
