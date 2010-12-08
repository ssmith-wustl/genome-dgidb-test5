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
                'common_name',
                'extraction_label',
                'extraction_type',
                'extraction_desc',
                'cell_type',
                'tissue_label',
                'tissue_desc',
                'organ_name',
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
                            name => 'builds',
                            aspects => [
                                'id', 'data_directory', 'status', 'date_scheduled', 'date_completed',
                            ],
                            perspective => 'default',
                            toolkit => 'xml',
                            subject_class_name => 'Genome::Model::Build',
                        },
                        'region_of_interest_set_name',
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
                {
                    name => 'projects',
                    subject_class_name => 'Genome::Site::WUGC::Project',
                    perspective => 'default',
                    toolkit => 'xml',
                    aspects => [
                        'id',
                        'name',
                        'status',
                        'description',
                        'project_type',
                        'mailing_list',
                        {
                            name => 'external_contact',
                            perspective => 'default',
                            toolkit => 'xml',
                            aspects => [
                                'id',
                                'email',
                                'name',
                                'type',
                            ]
                        },
                        {
                            name => 'internal_contact',
                            perspective => 'default',
                            toolkit => 'xml',
                            aspects => [
                                'id',
                                'email',
                                'name',
                                'type',
                            ]
                        },
                    ]
                }
            ]
        }
    ]
};


1;
