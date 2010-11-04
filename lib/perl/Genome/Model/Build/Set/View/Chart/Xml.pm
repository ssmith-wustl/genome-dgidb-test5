package Genome::Model::Build::Set::View::Chart::Xml;

use strict;
use warnings;

use Genome;

class Genome::Model::Build::Set::View::Chart::Xml {
    is => 'Genome::View::Status::Xml',
    has_constant => [
        default_aspects => {
            is => 'ARRAY',
            value => [
                'rule_display',
                {
                    name => 'members',
                    perspective => 'default',
                    toolkit => 'xml',
                    aspects => [
                        'id',
                        'data_directory',
                        'status',
                        'date_scheduled',
                        'date_completed',
                        'run_by',
                        {
                            name => 'metrics',
                            aspects => [
                                'name',
                                'value'
                            ],
                            perspective => 'default',
                            toolkit => 'xml',
                            subject_class_name => 'Genome::Model::Metric',
                        }
                    ],
                    subject_class_name => 'Genome::Model::Build',
                },
            ]
        }
    ]
};


1;
