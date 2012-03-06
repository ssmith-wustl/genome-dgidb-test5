package Genome::Model::Build::View::Fast::Xml;

use strict;
use warnings;

use Genome;

class Genome::Model::Build::View::Fast::Xml {
    is => 'Genome::View::Status::Xml',
    has_constant => [
        default_aspects => {
            is => 'ARRAY',
            value => [
                'id',
                'master_event_status',
                'data_directory',
                'notes',
                'run_by',
                'software_revision',
                '_newest_workflow_instance',
                {
                    'name' => 'the_master_event',
                    'perspective' => 'default',
                    'toolkit' => 'xml',
                    'aspects' => ['lsf_job_id'],
                },
                {
                    'name' => 'model',
                    'perspective' => 'default',
                    'toolkit' => 'xml',
                    'aspects' => [
                        'id',
                        'name',
                        'user_name',
                        {   'name' => 'processing_profile',
                            'perspective' => 'default',
                            'toolkit' => 'xml',
                            'aspects' => ['id', 'name'],
                        },
                        {
                            'name' => 'subject',
                            'perspective' => 'default',
                            'toolkit' => 'xml'
                        }
                    ],
                },
                {
                    'name' => 'inputs',
                    'perspective' => 'default',
                    'toolkit' => 'xml',
                    'aspect' => ['name']
                },
            ]
        }
    ]
};



1;
