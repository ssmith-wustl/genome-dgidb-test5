package Genome::Sample::View::Status::Xml;

use strict;
use warnings;

use Genome;

class Genome::Sample::View::Status::Xml {
    is => 'Genome::View::Status::Xml',
    has_constant => [
        default_aspects => {
            is => 'ARRAY',
            value => [
                'id',
                'name',
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
                        {
                            name => 'processing_profile',
                            aspects => ['id', 'name'],
                            perspective => 'default',
                            toolkit => 'xml'
                        },
                        'creation_date',
                        'user_name',
                        {
                            name => 'last_succeeded_build',
                            aspects => [
                                'id', 'data_directory'
                            ],
                            perspective => 'default',
                            toolkit => 'xml',
                            subject_class_name => 'Genome::Model::Build',
                        }
                    ],
                    subject_class_name => 'Genome::Model',
                },
                {
                    name => 'taxon',
                    perspective => 'default',
                    toolkit => 'xml',
                    aspects => [
                        'id',
                        'species_name',
                        'species_latin_name',
                        'strain_name',
                        
                    ]
                },
                {
                    name => 'source',
                    perspective => 'default',
                    toolkit => 'xml',
                    aspects => [
                        'id',
                        'name',
                        'common_name',
                    ]
                },
                {
                    name => 'libraries',
                    perspective => 'default',
                    toolkit => 'xml',
                    aspects => [
                        'id',
                        'name',
                    ]
                },
                #TODO include attributes
            ]
        }
    ]
};


1;
