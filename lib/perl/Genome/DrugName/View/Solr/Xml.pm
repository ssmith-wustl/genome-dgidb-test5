package Genome::DrugName::View::Solr::Xml;

use strict;
use warnings;

use Genome;

class Genome::DrugName::View::Solr::Xml {
    is => 'Genome::View::Solr::Xml',
    has => [
        type => {
            is => 'Text',
            default => 'drug-name'
        },
        display_type => {
            is  => 'Text',
            default => 'DrugName',
        },
        display_icon_url => {
            is  => 'Text',
            default => 'genome_drug-name_32',
        },
        display_url0 => { #TODO: make this url legit
            is => 'Text',
            calculate => q { 
                    my $subject = $self->subject;
                    return join ('?id=', '/view/genome/drug-name/status.html',$subject->id()); 
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
