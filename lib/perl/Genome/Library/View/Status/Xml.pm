package Genome::Library::View::Status::Xml;

use strict;
use warnings;

use Genome;

class Genome::Library::View::Status::Xml {
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
                    name => 'sample',
                    perspective => 'default',
                    toolkit => 'xml',
                    aspects => [
                        'id',
                        'name',
                    ]
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
                        'ncbi_taxon_id',
                    ]
                }
            ]
        }
    ]
};


1;
