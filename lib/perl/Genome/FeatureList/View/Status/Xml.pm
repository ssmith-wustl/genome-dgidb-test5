package Genome::FeatureList::View::Status::Xml;

use strict;
use warnings;

use Genome;

=cut

        file_id => { is => 'NUMBER', len => 20, doc => 'ID of the file storage for the BED file in LIMS' },
        disk_allocation   => { is => 'Genome::Disk::Allocation', calculate_from => [ 'class', 'id' ],
            calculate => q(
                my $disk_allocation = Genome::Disk::Allocation->get(
                    owner_class_name => $class,
                    owner_id => $id,
                );
                return $disk_allocation;
            )
        },
        file_path => {
            is => 'Text',
            calculate_from => ['disk_allocation'],
            calculate => q{
                if($disk_allocation) {
                    my $directory = $disk_allocation->absolute_path;
                    return join('/', $directory, $self->id . '.bed');
                } else {
                    return $self->_resolve_lims_bed_file;
                }
            },
        },

        #TODO This will point to a subclass of Genome::Feature at such point as that class exists.
        content_type => { is => 'VARCHAR2', len => 255, doc => 'The kind of features in the list' },

=cut

class Genome::FeatureList::View::Status::Xml {
    is => 'Genome::View::Status::Xml',
    has_constant => [
        default_aspects => {
            is => 'ARRAY',
            value => [
                'id',
                'name',
                'format',
                'file_content_hash',
                'is_multitracked',
                'is_1_based',
                'source',
                'reference_id',
                {
                    name => 'reference',
                    perspective => 'default',
                    toolkit => 'xml',
                    aspects => [
                        'id', 'data_directory', 'status', 'date_scheduled', 'date_completed', 'name',
                        {
                            name => 'model',
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
                            'region_of_interest_set_name',
                            ],
                            subject_class_name => 'Genome::Model',
                        }
                    ],
                },
                'subject_id',
                {
                    name => 'subject',
                    perspective => 'default',
                    toolkit => 'xml',
                    aspects => [
                        'id', 'data_directory', 'status', 'date_scheduled', 'date_completed',
                        {
                            name => 'model',
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
                            'region_of_interest_set_name',
                            ],
                            subject_class_name => 'Genome::Model',
                        }
                    ],
                },
                'file_id',
                'content_type',
                {
                    name => 'disk_allocation',
                    perspective => 'default',
                    toolkit => 'xml',
                    aspects => ['absolute_path'],
                },
            ]
        }
    ]
};

1;
