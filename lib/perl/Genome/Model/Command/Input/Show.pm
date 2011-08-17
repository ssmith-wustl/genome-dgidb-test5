package Genome::Model::Command::Input::Show;

use strict;
use warnings;

use Genome;
      
use Regexp::Common;
require Term::ANSIColor;

class Genome::Model::Command::Input::Show {
    is => 'Command',
    doc => 'Show the inputs of a model or type.',
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

    my $model = $self->_resolve_model_from_param;
    return if not $model;

    my @properties = eval{ $model->real_input_properties };
    return if not @properties;

    my @headers = "Inputs for ".( ref $model ? $model->__display_name__ : $model);
    push @headers, (qw/ VALUES /) if ref $model;
    push @headers, (qw/ COMMAND /);
    my @widths = map { length } @headers;
    my @rows;
    for my $property ( @properties ) {
        my @row;
        push @rows, \@row;
        my $name = $property->{name};
        $widths[0] = length $name if length $name > $widths[0];
        push @row, $name;
        if ( ref $model ) {
            my @values;
            for my $value ( $model->$name ) {
                push @values, ( ref $value ? $value->id : $value );
            }
            @values = ( 'NULL' ) if not grep { defined } @values;
            my $value = join(',', @values);
            push @row, $value;
            $widths[1] = length $value if not $widths[1] or length $value > $widths[1];
        }
        push @row, ( $property->{is_many} ? 'add/remove' : 'update' );
    }

    my $i = 0;
    @headers = map {
        $_ .= ' ' x ( $widths[$i] - length($_) );
        $i++;
        $_;
    } @headers;
    $i = 0;
    my @dashes = map {
        my $dash = '-' x length($_);
        $dash .= ' ' x ( $widths[$i] - length($dash) );
        $i++;
        $dash;
    } @headers;
    my $string = join("\t", @headers)."\n";
    $string .= join("\t", @dashes)."\n";
    for my $row ( @rows ) {
        $i = 0;
        map {
            $_ .= ' ' x ( $widths[$i] - length($_) );
            $i++;
            $_;
        } @$row;
        $string .= join("\t", @$row)."\n";
    }
    $string .= "\n";
    $self->status_message($string);

    return 1;
}

sub _resolve_model_from_param {
    my $self = shift;

    my $param = $self->model;

    if ( $param =~ /^$RE{num}{int}$/ ) {
        return Genome::Model->get($param);
    }

    my $model = Genome::Model->get(name => $param);
    return $model if $model;

    my $class = 'Genome::Model::';
    if ( $param =~ /^Genome::Model::/ ) { # class w/ G::M::
        $class .= $param;
    }
    else {
        my $subclass = Genome::Utility::Text::string_to_camel_case($param);
        $class .= $subclass;
    }

    my $rv = eval{ $class->__meta__; };
    return $class if $rv;
    $self->error_message("Failed to find model class ($class) for '$param'");
    return;
}

1;

