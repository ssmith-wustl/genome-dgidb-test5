package Genome::Model::Report;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Report {
    is => 'Genome::Report::Generator',
    has => [
    build => {
        is => 'Genome::Model::Build', 
        id_by => 'build_id'
    },
    build_id => {
        is => 'Integer', 
        doc=> 'Build id'
    },
    model => {
        is => 'Genome::Model', 
        via => 'build'
    },
    model_id => {
        via => 'model',
        to => 'id',
    },
    model_name => {
        via => 'model',
        to => 'name',
    },
    ],
};

sub create {
    my ($class, %params) = @_;

    unless ( $params{build_id} ) {
        $class->error_message("A build id is required to create a model report");
        return;
    }

    my $self = $class->SUPER::create(%params)
        or return;

    unless ( $self->build ) {
        $self->error_message( sprintf('Can\'t get a build for build_id (%s)', $self->build_id) );
        return;
    }

    return $self;
}

1;

#$HeadURL$
#$Id$
