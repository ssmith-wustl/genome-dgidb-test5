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
                        'creation_date',
                        'user_name',
                    ],
                },
            ]
        }
    ]
};


1;
