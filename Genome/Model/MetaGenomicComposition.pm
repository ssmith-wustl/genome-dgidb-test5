package Genome::Model::MetaGenomicComposition;

use strict;
use warnings;

use Genome;

use Genome::Consed::Directory;
use Genome::ProcessingProfile::MetaGenomicComposition;

class Genome::Model::MetaGenomicComposition {
    is => 'Genome::Model',
    has => [
    read_set_assignment_events =>{
        is => 'Genome::Model::Command::Build::Assembly::AssignReadSetToModel',
        is_many => 1,
        reverse_id_by => 'model',
        where => [ "event_type like" => 'genome-model build assembly assign-read-sets%'],
        doc => 'each case of a read set being assigned to the model',
    },
    map({
            $_ => {
                via => 'processing_profile',
            }
        } Genome::ProcessingProfile::MetaGenomicComposition->params_for_class
    ),
    ],
};

sub _test {
    # Hard coded param for now
    return 1;
}

sub _build_subclass_name {
    return 'assembly';
}

sub _assembly_directory {
    my $self = shift;
    return $self->data_directory . '/assembly';
}

sub consed_directory { 
    return Genome::Consed::Directory->create(directory => $_[0]->data_directory);
}

1;

=pod
=cut

#$HeadURL$
#$Id$
