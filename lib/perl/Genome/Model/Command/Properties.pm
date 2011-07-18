package Genome::Model::Command::Properties;

use strict;
use warnings;

use Genome;
      
use Regexp::Common;
require Term::ANSIColor;

class Genome::Model::Command::Properties {
    is => 'Command',
    doc => 'Lists the properties of a model or type.',
    has => [
        model => {
            is => 'Text',
            shell_args_position => 1,
            doc => 'A model id, name, type or class.'
        },
    ],
};

sub execute {
    my $self = shift;

    my $model = $self->_resolve_param;
    return if not $model;

    my @properties = $model->property_names_for_copy;
    return if not @properties;

    if ( ref $model ) {
        return $self->_print_model_properties_and_values($model, @properties);
    }

    my $string = Term::ANSIColor::colored("Properties for class $model", 'bold')."\n";
    for my $property ( @properties ) {
        $string .= Term::ANSIColor::colored($property, 'red')."\n";
    }
    $self->status_message($string);

    return 1;
}

sub _resolve_param {
    my $self = shift;

    my $param = $self->model;

    my $model;
    if ( $param =~ /^$RE{num}{int}$/ ) {
        $model = Genome::Model->get($param);
    }
    else { 
        $model = Genome::Model->get(name => $param);
    }

    if ( $model ) {
        return $model
    }

    if ( $param =~ /^Genome::Model::/ ) { # class w/ G::M::
        return $param;
    }
    else {
        my $subclass = Genome::Utility::Text::string_to_camel_case($param);
        return 'Genome::Model::'.$subclass;
    }
}

sub _print_model_properties_and_values {
    my ($self, $model, @properties) = @_;

    my $string = Term::ANSIColor::colored("Properties for model ".$model->__display_name__, 'bold')."\n";
    for my $name ( @properties ) {
        my @values;
        for my $value ( $model->$name ) {
            my $converted_value = $value;
            if ( my $ref = ref $value ) {
                $converted_value = $value->id;
            }
            push @values, $converted_value;
        }
        push @values, 'undef' if not @values;
        $string .= Term::ANSIColor::colored($name, 'red').' '.join(' ', @values)."\n";
    }

    $self->status_message($string);

    return 1
}

1;

