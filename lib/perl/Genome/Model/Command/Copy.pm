package Genome::Model::Command::Copy;

use strict;
use warnings;

use Genome;

use Regexp::Common;

class Genome::Model::Command::Copy {
    class_name => __PACKAGE__,    
    is => 'Genome::Command::Base',
    has => [
        model => {
            is => 'Genome::Model',
            shell_args_position => 1,
            doc => 'The source model to copy.'
        },
        overrides => {
            is_many => 1,
            is_optional => 1,
            shell_args_position => 3,
            doc => 'Properties to override in the new model. Properties include name, subject, processing_profile, instrument_data, auto_build_alignments, auto_assign_inst_data and all model inputs.'
        },
        _new_model => { is_optional => 1, }
    ],
    doc => 'create a new genome model based on an existing one'
};

sub sub_command_sort_position { 2 }

sub help_synopsis {
    return <<"EOS"
Copy model 123456789 to new model using default name and overriding the subject

 genome model copy 123456789 subject=name=H_SAMPLE

Copy model 123456789 to new model with name "Copy of my Awesome Model", overriding processing profile and auto build alignments:

 genome model copy 123456789 "name=Copy of my Awesome Model" processing_profile="use this processing profile instead" auto_build_alignments=0

EOS
}

sub help_detail {
    return <<"EOS"
* Copy a model to a new model overriding some of the original model's properties. This will copy the model's definition only, and not any builds.
 
* Override properties are actual model properties. If you want to override reference_sequence_build, you use that, and not reference_sequence_build_id. Give override as space separated bare arguments. Use the format: property=value. The value can be an id or filter string.  If the property can have many values, use a filter string, or multiple key=value pairs. To set something to undefined, use 'property='.

Model properties that can be overridden:

auto_build_alignments
auto_assign_inst_data
instrument_data (or use do_not_copy_instrument_data to not add any)
name
processing_profile
subject

All other model inputs can be overriden. See model input names and values with:
 genome model input list --f model_id=\$FROM_MODEL_ID

* Examples

processing_profile=\$ID
processing_profile=name=\$NAME
instrument_data=library_id=\$LIB_ID
db_dnp_build=id=\$DB_SNP_ID

Unfortunately, there cannot be commas in the filter string:

db_snp_build=model_id=\$MODEL_ID,status=Succeeded

To set any property to undefined:

'property='

* Name of the new model is an override. You no longer need to specify a name. If no name is given, the default name will be used. If a model with the same name and type exist, you will need to provide a name. To specify a new name:

name=\$NEW_NAME

* Subject can be overriden:

subject=\$ID
subject=name=\$NAME
subject=common_name=\$NAME

* Instrument data is an override. Instrument data is a many property, so you can use a filter or multiple instrument data overrides. To specify the instrument data for the model:

instrument_data=\$ID1
instrument_data=\$ID1 instrument_data=\$ID2
instrument_data=library_id=\$LIB_ID

To not copy/assign any instrument data, set it to undef. The do_not_copy_inst_data option has been removed.

'instrument_data='

EOS
}

sub execute {
    my $self = shift;

    my $model = $self->model;
    if ( not $model ) {
        $self->error_message('No model to copy');
        return;
    }
    $self->status_message('Copy model: '.$model->__display_name__);

    my %overrides = $model->class->params_from_param_strings($self->overrides); 
    return if not %overrides;

    my $new_model = $model->copy(%overrides);
    return if not $new_model;
    $self->_new_model($new_model);

    $self->status_message("Success!\nNew model: ".$new_model->__display_name__);

    return 1;
}

1;

