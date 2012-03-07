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
                            'toolkit' => 'xml',
                            'aspects' => ['id'],
                        }
                    ],
                },
                {
                    'name' => 'inputs',
                    'perspective' => 'default',
                    'toolkit' => 'xml',
                    'aspects' => ['name']
                },
            ]
        }
    ]
};


sub _generate_content {

    my ($self) = @_;
    my $b = $self->subject();

    # get this stuff now so we dont have to later
    Genome::Model::Build::Input->get(
        'build_id' => $b->id,
        '-hint' => ['value_model','value_build','value_inst_data']
    );
 
    return $self->SUPER::_generate_content();
}



1;
