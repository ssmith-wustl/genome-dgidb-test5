package Genome::Model::Set::View::Status::Xml;

use strict;
use warnings;

use Genome;

class Genome::Model::Set::View::Status::Xml {
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
                        'genome_model_id',
                        'name',
                        'subject_id',
                        'subject_class_name',
                        'is_default',
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
                    ],
                    subject_class_name => 'Genome::Model',
                },
            ]
        }
    ]
};


1;
