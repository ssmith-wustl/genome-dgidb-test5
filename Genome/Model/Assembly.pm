package Genome::Model::Assembly;

use strict;
use warnings;

use Genome;

class Genome::Model::Assembly {
    is => 'Genome::Model',
    has => [
            assignment_events    => { is => 'Genome::Model::Command::Build::Assembly::AssignReadSetToModel',
                                     is_many => 1,
                                     reverse_id_by => 'model',
                                     where => [ "event_type like" => 'genome-model build assembly assign-read-sets%'],
                                     doc => 'each case of an instrument data being assigned to the model',
                                 },
            assembler_name       => { via => 'processing_profile', },
            assembler_params     => { via => 'processing_profile', },
	    assembler_version    => { via => 'processing_profile', },
	    version_subdirectory => { via => 'processing_profile', },
            read_filter_name     => { via => 'processing_profile', },
            read_filter_params   => { via => 'processing_profile', },
            read_trimmer_name    => { via => 'processing_profile', },
            read_trimmer_params  => { via => 'processing_profile', },
        ],
};

sub build_subclass_name {
    return 'assembly';
}

sub assembly_directory {
    my $self = shift;
    return $self->data_directory . '/assembly';
}

sub sff_directory {
    my $self = shift;
    return $self->data_directory . '/sff';
}

sub assembly_project_xml_file {
    my $self = shift;
    return $self->assembly_directory .'/454AssemblyProject.xml'
}
1;
