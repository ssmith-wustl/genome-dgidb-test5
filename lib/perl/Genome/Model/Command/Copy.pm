package Genome::Model::Command::Copy;

use strict;
use warnings;

use Genome;

use Regexp::Common;

class Genome::Model::Command::Copy {
    class_name => __PACKAGE__,    
    is => 'Genome::Command::Base',
    has => [
        from => {
            is => 'Genome::Model',
            shell_args_position => 1,
            doc => 'The source model to copy.'
        },
        to => {
            is => 'Text',
            len => 255,
            shell_args_position => 2,
            doc => 'The name of the new model that will be created'
        },
        overrides => {
            is_many => 1,
            is_optional => 1,
            shell_args_position => 3,
            doc => 'Properties to override in the new model.'
        },
        do_not_copy_instrument_data => {
            is => 'Boolean',
            is_input => 1,
            is_optional => 1,     
            default_value => 0,
            doc => 'Do not copy instrument to the new model.'
        },
        _copied_model => { is_optional => 1, }
    ],
    doc => 'create a new genome model based on an existing one'
};

sub sub_command_sort_position { 2 }

sub help_synopsis {
    return <<"EOS"
 genome model copy --from 123456789 --to "copy_of_my_model" --overrides processing_profile="use this processing profile instead" --overrides auto_build_alignments=0
    
 genome model copy 123456789 copy_of_my_model processing_profile="use this processing profile instead" auto_build_alignments=0
EOS
}

sub help_detail {
    return <<"EOS"
This defines a new genome model.

An existing model is used as a template, with its parameters and instrument data assignments
being used to create the new model.

Individual parameters on the model can be overriden by passing key-value pairs on the command line.
For example, use

   processing_profile="example profile" # id or name

to have the resulting model be defined using <example profile> instead of the processing profile
assigned to the source model.  (See the corresponding lister for a list of properties that can be overridden in this way.) If named (rather than positional) arguments are used, "--overrides" must precede each key-value pair.

The copy command only copies the definitions.  It does not copy any underlying model data.

EOS
}

sub execute {
    my $self = shift;

    my $model = $self->from;
    if ( not $model ) {
        $self->error_message('No model to copy');
        return;
    }

    my $new_name = $self->to;
    if ( not $new_name ) {
        $self->error_message('No new for new model');
        return;
    }

    my %overrides = (
        name => $new_name,
        do_not_copy_instrument_data => $self->do_not_copy_instrument_data,
    );
    for my $override ( $self->overrides ) {
        my ($key, $value_str) = split('=', $override, 2);
        my @values = split(',', $value_str);
        if ($model->__meta__->property($key)->is_many) {
            $overrides{$key} = \@values;
        } else {
            if (scalar(@values) > 1) {
                $self->error_message('Multiple values passed for single property: '.$key);
                return;
            } else {
                $overrides{$key} = $values[0];
            }
        }
    }

    if ( $overrides{processing_profile} ) {
        my $override_pp = $self->_get_override_processing_profile($model->processing_profile->class, $overrides{processing_profile});
        return if not $override_pp;
        $overrides{processing_profile} = $override_pp;
    }

    my $new_model = $model->copy(%overrides);
    if ( not $new_model ) {
        $self->error_message('Failed to copy model');
        return;
    }
    $self->_copied_model($new_model);

    $self->status_message('Copy was successful. New model: '.$new_model->__display_name__);

    return 1;
}

sub _get_override_processing_profile {
    my ($self, $pp_class, $override_id) = @_;

    my %get_params = ( $override_id =~ /^$RE{num}{int}$/ )
    ? ( id => $override_id )
    : ( name => $override_id );

    my $override_pp = $pp_class->get(%get_params);
    if ( not $override_pp ) {
        $self->error_message("Failed to get processing profile for $override_id");
        return;
    }

    return $override_pp;
}

1;
