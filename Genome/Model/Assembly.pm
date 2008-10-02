package Genome::Model::Assembly;

use strict;
use warnings;

use Genome;

class Genome::Model::Assembly {
    is => 'Genome::Model',
    has => [
            read_set_assignment_events   => { is => 'Genome::Model::Command::Build::Assembly::AssignReadSetToModel',
                                              is_many => 1,
                                              reverse_id_by => 'model',
                                              where => [ "event_type like" => 'genome-model build assembly assign-read-sets%'],
                                              doc => 'each case of a read set being assigned to the model',
                                        },
            assembler           => { via => 'processing_profile', },
            assembler_params    => { via => 'processing_profile', },
            read_filter         => { via => 'processing_profile', },
            read_filter_params  => { via => 'processing_profile', },
            read_trimmer        => { via => 'processing_profile', },
            read_trimmer_params => { via => 'processing_profile', },
        ],
};

sub test {
    # Hard coded param for now
    return 1;
}

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

1;
