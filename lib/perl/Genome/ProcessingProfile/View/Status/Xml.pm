package Genome::ProcessingProfile::View::Status::Xml;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::View::Status::Xml {
    is => 'Genome::View::Status::Xml',
    has_constant => [
        default_aspects => {
            is => 'ARRAY',
            value => [
                'id',
                'name',
                'type_name',
                'supersedes',
                {
                    name => 'params',
                    perspective => 'default',
                    toolkit => 'xml',
                    aspects => [
                        'id', 'name', 'value',
                    ]
                },
                {
                    name => 'models',
                    perspective => 'default',
                    toolkit => 'xml',
                    aspects => [
                        'genome_model_id',
                        'name',
                        'subject_id',
                        'subject_class_name',
                        'is_default',
                        'data_directory',
                        'creation_date',
                        'user_name',
                        {
                            name => 'builds',
                            aspects => [
                                'id', 'data_directory', 'status', 'date_scheduled', 'date_completed',
                            ],
                            perspective => 'default',
                            toolkit => 'xml',
                            subject_class_name => 'Genome::Model::Build',
                        },
                        {
                            name => 'last_complete_build',
                            aspects => [
                                'id', 'data_directory', 'status', 'date_scheduled', 'date_completed',
                            ],
                            perspective => 'default',
                            toolkit => 'xml',
                            subject_class_name => 'Genome::Model::Build',
                        }

#This is pretty slow. Bring it back if it turns out to be wanted.
#                        {
#                            name => 'last_succeeded_build',
#                            aspects => [
#                                'id', 'data_directory', 'status',
#                            ],
#                            perspective => 'default',
#                            toolkit => 'xml',
#                            subject_class_name => 'Genome::Model::Build',
#                        }
                    ],
                },
            ]
        }
    ]
};


1;
