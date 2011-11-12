package Genome::DruggableGene::DrugGeneInteractionReport::View::Solr::Xml;

use strict;
use warnings;

use Genome;

class Genome::DruggableGene::DrugGeneInteractionReport::View::Solr::Xml {
    is => 'Genome::View::Solr::Xml',
    has => [
        type => {
            is => 'Text',
            default => 'drug-gene-interaction-report'
        },
        display_type => {
            is  => 'Text',
            default => 'DrugGeneInteractionReport',
        },
        display_icon_url => {
            is  => 'Text',
            default => 'genome_druggable-gene_drug-gene-interaction-report_32',
        },
        display_url0 => {
            is => 'Text',
            calculate_from => ['subject'],
            calculate => q{
                return join ('?id=', '/view/genome/druggable-gene/drug-gene-interaction-report/status.html',$_->id());
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
                    name => '__display_name__',
                    position => 'title',
                },
                {
                    name => 'drug_name_report',
                    position => 'content',
                    perspective => 'default',
                    toolkit => 'text',
                    aspects => [
                        'id',
                        'name',
                        'nomenclature',
                        'source_db_name',
                        'source_db_version'
                    ]
                },
                {

                    name => 'gene_name_report',
                    position => 'content',
                    perspective => 'default',
                    toolkit => 'text',
                    aspects => [
                        'id',
                        'name',
                        'nomenclature',
                        'source_db_name',
                        'source_db_version'
                    ]
                },
                {
                    name => 'interaction_type',
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
