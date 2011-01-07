package Genome::Model::View::Solr::Xml;

use strict;
use warnings;

use Genome;

class Genome::Model::View::Solr::Xml {
    is => 'Genome::View::Solr::Xml',
    has_constant => [
        type => {
            is => 'Text',
            default => 'model'
        },
        display_type => {
            is  => 'Text',
            default => 'Model',
        },
        display_icon_url => {
            is  => 'Text',
            default => 'genome_model_32.png',
        }
        default_aspects => {
            is => 'ARRAY',
            default => [
                {
                    name => 'creation_date',
                    position => 'timestamp',
                },
                {
                    name => 'build_ids',
                    position => 'content',
                },
                {
                    name => 'processing_profile',
                    position => 'content',
                    perspective => 'default',
                    toolkit => 'text',
                    aspects => [
                        'id',
                        'name'
                    ]
                },
                {
                    name => 'data_directory',
                    position => 'content',
                },
                {
                    name => 'display_name',
                    position => 'display_title',
                }
# Loading instrument data is *so* slow
#                {
#                    name => 'instrument_data',
#                    position => 'content',
#                    perspective => 'default',
#                    toolkit => 'text',
#                    aspects => [
#                        'id',
#                        'run_name',
#                    ]
#                }
            ],
        }
    ]
};

#x display_title
#x display_type
#display_icon_url
#                
#display_content
#                
#display_label1 
#display_url1
#                
#display_label2
#display_url2
#                
#display_label3
#display_url3


