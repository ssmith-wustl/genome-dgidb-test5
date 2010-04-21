package Genome::Taxon::View::Status::Xml;

use strict;
use warnings;

use Genome;

class Genome::Taxon::View::Status::Xml {
    is => 'Genome::View::Status::Xml',
    has_constant => [
        default_aspects => {
            is => 'ARRAY',
            value => [
                'id',
                'species_name',
                'species_latin_name',
                'strain_name',
                {
                    name => 'model_member',
                    perspective => 'default',
                    toolkit => 'xml',
                    aspects => [
                        'id',
                        'name',
                        'common_name',
                        {
                            name => 'samples',
                            perspective => 'default',
                            toolkit => 'xml',
                            aspects => [
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
                                }
                            ]
                        }
                    ]
                },
                {
                    name => 'individuals',
                    perspective => 'default',
                    toolkit => 'xml',
                    aspects => [
                        'id',
                        'name',
                        'common_name',
                        'gender',
                        {
                            name => 'samples',
                            perspective => 'default',
                            toolkit => 'xml',
                            aspects => [
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
                                            aspects => [ 'id', 'data_directory' ],
                                            perspective => 'default',
                                            toolkit => 'xml',
                                            subject_class_name => 'Genome::Model::Build',
                                        }
                                    ],
                                    subject_class_name => 'Genome::Model',
                                }
                            ]
                        }
                    ]
                },
                {
                    name => 'population_groups',
                    perspective => 'default',
                    toolkit => 'xml',
                    aspects => [
                        'id',
                        'name',
                        'common_name',
                        {
                            name => 'samples',
                            perspective => 'default',
                            toolkit => 'xml',
                            aspects => [
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
                                }
                            ]
                        }
                    ]
                },
            ]
        }
    ]
};


1;
