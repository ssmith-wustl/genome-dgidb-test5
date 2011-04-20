package Genome::Model::Input;

use strict;
use warnings;

use Genome;

require Carp;

class Genome::Model::Input {
    type_name => 'genome model input',
    table_name => 'GENOME_MODEL_INPUT',
    id_by => [
        value_class_name => { is => 'VARCHAR2', len => 255 },
        value_id         => { is => 'VARCHAR2', len => 1000, implied_by => 'value' },
        model_id         => { is => 'NUMBER', len => 11, implied_by => 'model' },
        name             => { is => 'VARCHAR2', len => 255 },
    ],
    has => [
        model        => { is => 'Genome::Model', id_by => 'model_id', constraint_name => 'GMI_GM_FK' },
        model_name   => { via => 'model', to => 'name' },

        # i think this...
        value        => { is => 'UR::Object', id_by => 'value_id', id_class_by => 'value_class_name' },
        
        # was supposed to be this...?

        # value_object => { is => 'UR::Object', id_by => 'value_id', id_class_by => 'value_class_name' },
        # value        => { 
        #     calculate => q|$value_class_name->isa("UR::Value") ? $value_object : $value_id| 
        #     calculate_from => [qw/value_class_name value_id value_object/], 
        # }, 
        filter_desc => { 
            is => 'Text',
            len => 100,
            is_optional => 1, 
            valid_values => [ 'forward-only', 'reverse-only', undef ],
            doc => 'Filter to apply on the input value.'
        },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

sub __display_name__ {
    my $self = shift;
    return $self->value_class_name . ': ' . $self->value_id;
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    return if not $self;

    my $model = $self->model;
    Carp::confess('No model to create input') if not $model;
    my $name = $self->name;
    Carp::confess('No name to create input') if not $name;
    my $obj = $self->value;
    Carp::confess('No value to create input') if not $obj;

    $self->status_message('Create input '.$self->name.' '.$self->value_id.' for model '.$model->id);

    if ( $self->name ne 'instrument_data' ) {
        return $self;
    }

    my $ida = Genome::Model::InstrumentDataAssignment->create(
        model => $model,
        instrument_data => $obj,
    );
    if ( not $ida ) {
        $self->status_message('Cannot create ida for input '.$self->name.' '.$self->value_id.' for model '.$model->__display_name__);
        return;
    }
    $ida->filter_desc( $self->filter_desc ) if $self->filter_desc;

    return $self;
}

sub delete {
    my $self = shift;

    my $model = $self->model;
    Carp::confess('No model to delete input') if not $model;
    my $name = $self->name;

    $self->status_message("Delete input $name ".$self->value_id.' for model '.$model->__display_name__);

    return $self->SUPER::delete if $self->name ne 'instrument_data';

    my $ida = Genome::Model::InstrumentDataAssignment->get(
        model => $model,
        instrument_data_id => $self->value_id,
    );
    if ( $ida ) { # ignore if not found
        my $delete = $ida->delete;
        if ( not $delete ) {
            Carp::confess('Could not delete instrument data assignment');
        }
    }

    my @builds = $model->builds;
    for my $build ( @builds ) {
        my ($build_has_input) = grep { 
            $_->name eq $name 
                and $_->value_id eq $self->value_id 
        } $build->inputs;
        next if not $build_has_input;
        $self->status_message('Abandoning build with this input: '.$build->__display_name__);
        my $abandon = eval{ $build->abandon; };
        if ( not $abandon ) {
            Carp::confess('Failed to abandon build ('.$build->__display_name__.') while deleting input');
        }
    }

    return $self->SUPER::delete;
}

1;

