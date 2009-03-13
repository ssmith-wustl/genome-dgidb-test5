package Genome::Model::Report;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Report {
    is => 'Genome::Report',
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

sub get_or_create {
    my ($class, %params) = @_;

    unless ( $params{build_id} ) {
        $class->error_message("A build id is required to create a model report");
        return;
    }

    unless ( $params{parent_directory} ) {
        my $build = Genome::Model::Build->get(build_id => $params{build_id});
        unless ( $build) {
            $class->error_message("Can't get build for id: ".$params{build_id});
            return;
        }
        my $reports_directory = $build->resolve_reports_directory;
        Genome::Utility::FileSystem->create_directory($reports_directory)
            or return;
        $params{parent_directory} =  $reports_directory;
    }

    my $self = $class->SUPER::get_or_create(%params)
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
