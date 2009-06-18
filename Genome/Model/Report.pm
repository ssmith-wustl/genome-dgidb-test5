package Genome::Model::Report;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';

class Genome::Model::Report {
    is => ['Genome::Report::Generator','Genome::Utility::FileSystem'],
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

sub generate_report {
    my $self = shift;

    $self->_add_model_info
        or return;
    
    return $self->SUPER::generate_report;
}

sub _add_model_info {
    my $self = shift;

    my $build_node = $self->_xml->createElement('model-info')
        or return;
    $self->_main_node->addChild($build_node)
        or return;

    my %objects_attrs = (
        model => [qw/ name type_name subject_name subject_type /, $self->model->processing_profile->params_for_class ],
        build => [qw/ build_id data_directory /],
    );
    for my $object ( keys %objects_attrs ) {
        for my $attr ( @{$objects_attrs{$object}} ) {
            my $value = $self->$object->$attr;
            $attr =~ s#\_#\-#g;
            my $element = $build_node->addChild( $self->_xml->createElement($attr) )
                or return;
            $element->appendTextNode($value);
        }
    }

    return 1;
}

1;

#$HeadURL$
#$Id$
