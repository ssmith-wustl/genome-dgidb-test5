package Genome::Model::Build::Command::Base;

use strict;
use warnings;

use Genome;

use Regexp::Common;

class Genome::Model::Build::Command::Base {
    is => 'Command',
    is_abstract => 1,
    has_optional => [
        #< Build >#
        _build => {
            is => 'Genome::Model::Build',
        },
        build_id => {
            is => 'Number',
            doc => 'Get build by id.',
            is_optional => 1,
            shell_args_position => 1,
        },
        #< Model >#
        _model => { 
            is => 'Genome::Model',
        },
        model_identifier => { 
            is => 'Text',
            doc => 'Get the build by model. Use id or name.',
        },
        model_id => { 
            via => 'model',
            to => 'id',
        },
        model_name => { 
            via => 'model',
            to => 'name,'
        },
        method => {
            is => 'Text',
            default_value => 'current_running',
            valid_values => [qw/ 
            current_running last_succeeded last_complete 
            /],
            doc => 'If using model identifier, use this "method" to get the build.',
        },
    ],
};

#< Command >#
sub sub_command_dirs { return; } # over laod to not get INC error when base command looks for this class' directory
 
sub help_detail {
    return;
}

#< Build/Model Resolving >#
sub _resolve_build {
    my $self = shift;

    if ( defined $self->build_id ) {
        return $self->_get_build_for_id( $self->build_id );
    }

    if ( defined $self->model_identifier ) {
        return $self->_resolve_build_for_model_identifier( $self->model_identifier );
    }

    $self->error_message('No option given to resovle builds. Use build-id or model-identifier.');
    return ;
}

sub _get_build_for_id {
    my ($self, $build_id) = @_;

    unless ( defined $build_id ) { # check before calling this method
        die "No build id gievn to get build";
    }

    unless ( $self->build_id =~ /^$RE{num}{int}$/ ) {
        $self->error_message("Build id ($build_id) is not an integer, and cannot retreive build.");
        return;
    }

    my $build = Genome::Model::Build->get($build_id);
    unless ( $build ) {
        $self->error_message("Can't get build for id ($build_id).");
        return;
    }

    return $self->_build($build);
}

sub _resolve_build_for_model_identifier {
    my $self = shift;

    # Make sure we got an identifier
    my $model_identifier = $self->model_identifier;
    unless ( defined $model_identifier ) { # check before calling this method
        die "No model identifier gievn to get build";
    }

    my $model;
    # By id if it's an integer
    if ( $model_identifier =~ /^$RE{num}{int}$/ ) {
        $model = Genome::Model->get($model_identifier);
    }

    # Try by name if id wasn't an integer or didn't work
    unless ( $model ) { 
        $model = Genome::Model->get(name => $model_identifier);
    }

    # Neither worked
    unless ( $model ) {
        $self->error_message("Can't get model for identifier ($model_identifier).  Tried getting as id and name.");
        return;
    }

    $self->_model($model);

    my $method = $self->method.'_build';
    my $build = $model->$method;
    unless ( $build ) {
        $self->error_message("Got model for identifier ($model_identifier), but could not get a build for method (".$self->method.")");
        return;
    }
    
    $self->build_id( $build->id );
    
    return $self->_build($build);
}

1;

#$HeadURL$
#$Id$
