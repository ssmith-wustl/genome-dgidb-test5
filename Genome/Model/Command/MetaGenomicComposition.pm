package Genome::Model::Command::MetaGenomicComposition;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::MetaGenomicComposition {
    is => 'Genome::Model::Command',
    is_abstract => 1,
};

sub help_brief {
    return "Operations for MGC models";
}

sub help_detail {
    return help_brief();
}

sub _verify_mgc_model {
    my $self = shift;

    unless ( $self->model ) {
        $self->error_message("A model is required for this command");
        return;
    }

    unless ( $self->model->isa('Genome::Model::MetaGenomicComposition') ) {
        $self->error_message(
            sprintf(
                'Got a model (%s <ID: %s>), but it is not of type meta genomic composition', 
                $self->model->name,
                $self->model->id,
            ) 
        );
        $self->delete;
        return;
    }

    return 1;
}

1;

#$HeadURL$
#$Id$
