package Genome::Model::Command::MetaGenomicComposition;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::MetaGenomicComposition {
    is => 'Genome::Model::Command',
    is_abstract => 1,
};

sub help_brief {
    return "MGC";
}

sub help_detail {
    return <<"EOS"
EOS
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

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

    return $self;
}

1;

#$HeadURL$
#$Id$
