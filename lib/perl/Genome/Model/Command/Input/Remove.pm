package Genome::Model::Command::Input::Remove;

use strict;
use warnings;

use Genome;
      
use Regexp::Common;

class Genome::Model::Command::Input::Remove {
    is => 'Genome::Model::Command::Input',
    english_name => 'genome model input command remove',
    doc => 'Remove inputs to a model.',
    has => [
    name => {
        is => 'Text',
        doc => 'The name of the input to remove. Use the plural property name - friends to remove a friend',
    },
    'ids' => {
        is => 'Text',
        doc => 'The id(s) of the input. Separate multiple ids by commas.'
    },
    ],
    has_optional => [
    abandon_builds => {
        is => 'Boolean',
        default_value => 0,
        doc => 'Abandon (not remove) builds that have these inputs.',
    },
    ],
};

############################################

sub help_detail {
    return <<EOS;
    This command will remove inputs from a model. The input must be an 'is_many' property, meaning there must be more than one input allowed (eg: instrument_data). If the property is singular, use the 'update' command.
    
    Use the plural name of the property.
    
    To remove multiple inputs with the same name, separate the ids by a comma.

    Optionally, builds associated with these inputs may be abandoned.  Note that the builds are not removed, only abandoned.
EOS
}

############################################

sub execute {
    my $self = shift;

    # Validate name
    unless ( $self->name ) {
        $self->error_message('No input name given to remove from model.');
        return;
    }

    my $property = $self->_get_is_many_input_property_for_name( $self->name )
        or return;

    # Validate ids
    unless ( defined $self->ids ) {
        $self->error_message('No input ids given to remove  from model.');
        $self->delete;
        return;
    }

    my @ids = split(',', $self->ids);
    unless ( @ids ) {
        $self->error_message("No ids found in split of ".$self->ids);
        return;
    }
    
    # Get build ids via build inputs to abandon
    my $builds = $self->_get_builds
        or return;
    
    # Get the anon sub to do the removing
    my $sub = $self->_get_remove_sub_for_property($property)
        or return;
    for my $value ( @ids ) {
        unless ( $sub->($value) ) {
            $self->error_message("Can't remove input '".$self->name." ($value) from model.");
            return;
        }
    }

    # Abandon the builds
    $self->_abandon_builds($builds)
        or return;

    printf(
        "Removed %s (%s) from model.\n",
        ( @ids > 1 ? $property->property_name : $property->singular_name ),
        join(', ', @ids),
    );

    return 1; 
}

sub _get_remove_sub_for_property {
    my ($self, $property) = @_;

    my $property_name = $property->property_name;
    
    my $method = $self->_determine_and_validate_add_or_remove_method_name($property, 'remove')
        or return;
    
    #< Get the value class name or data type and createthe sub >#
    my ($value_class_name, $data_type);
    $self->_validate_where_and_resolve_value_class_name_or_data_type_for_property(
        $property, \$value_class_name, \$data_type
    ) or return;

    if ( $value_class_name ) {
        return sub{
            my $value = shift;
            
            my ($existing_value) = grep { $value eq $_ } $self->_model->$property_name;
            unless ( $existing_value ) {
                $self->error_message("Can't find existing value ($value) for model property ($property_name).");
                return;
            }

            return $self->_model->$method($value);
        };
    }

    return sub{
        my $value = shift;

        my ($existing_obj) = grep { $value eq $_->id } $self->_model->$property_name;
        unless ( $existing_obj ) {
            $self->error_message("Can't find existing $property_name ($data_type) for id ($value) to remove from model.");
            return;
        }

        return $self->_model->$method($existing_obj);
    };
}

sub _get_builds { # return \@builds for ok, undef for not
    my $self = shift;

    $DB::single = 1;
    my @builds;
    return \@builds unless $self->abandon_builds;
    
    #FIXME using inst_data in models, but instrument_data in builds
    # This needs to go away when we back fill
    my $name = $self->name;
    if ( $name eq 'inst_data' ) {
        $name = 'instrument_data';
    }
    my @build_inputs = Genome::Model::Build::Input->get( # go thru inputs to find builds
        #name => $self->name,
        name => $name,
        value_id => [ split(',', $self->ids) ],
    );

    return \@builds unless @build_inputs; # ok
    
    for my $input ( @build_inputs ) {
        my $build = $input->build;
        unless ( $build ) {
            $self->error_message("No build found for input build id: ".$input->build_id);
            return;
        }
        push @builds, $build;
    }

    return \@builds;
}

sub _abandon_builds {
    my ($self, $builds) = @_;

    return 1 unless $self->abandon_builds and @$builds;
    
    for my $build ( @$builds ) {
        eval{
            $build->abandon; # this can die
        };
        if ( $@ ) {
            $self->status_message(
                sprintf(
                    'Can\'t abandon build (%d) for model %s (%d): %s',
                    $build->id,
                    $build->model->name,
                    $build->model->id
                )
            );
            return;
        }
        $self->status_message(
            sprintf(
                'Abandoned build (%d) for model %s (%d)\n',
                $build->id,
                $build->model->name,
                $build->model->id
            )
        );
    }

    return 1;
}

1;

#$HeadURL$
#$Id$
