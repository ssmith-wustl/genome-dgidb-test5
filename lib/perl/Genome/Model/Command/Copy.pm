package Genome::Model::Command::Copy;

use strict;
use warnings;

use Genome;
use Data::Dumper;

require Genome::Sys;


class Genome::Model::Command::Copy {
    class_name => __PACKAGE__,    
    is => 'Genome::Command::Base',
    has => [
        from => {
            is => 'Genome::Model',
            id_by => '_from_model_id',
            is_input => 1,
            shell_args_position => 1,
            doc => 'The source model to copy from'
        },
        to => {
            is => 'Text',
            len => 255,
            is_input => 1,
            is_optional => 0,
            shell_args_position => 2,
            doc => 'The name of the new model that will be created'
        },
        skip_instrument_data_assignments => {
            is => 'Boolean',
            is_input => 1,
            is_optional => 1,     
            default_value => 0,
            doc => 'Skip assigning instrument data'
        },
        model_overrides => {
            is_many => 1,
            is_optional => 1,
            shell_args_position => 3,
        }
    ],
    has_optional => [
        _copied_model => {
            is => "Genome::Model",
            is_output => 1,
        }
    ],
    doc => 'create a new genome model based on an existing one'
};

sub sub_command_sort_position { 2 }

sub help_synopsis {
    return <<"EOS"
 genome model copy --from 123456789 --to "copy_of_my_model" --model-overrides processing_profile_name="use this processing profile instead" --model-overrides auto_build_alignments=0
    
 genome model copy 123456789 copy_of_my_model processing_profile_name="use this processing profile instead" auto_build_alignments=0
EOS
}

sub help_detail {
    return <<"EOS"
This defines a new genome model.

An existing model is used as a template, with its parameters and instrument data assignments
being used to create the new model.

Individual parameters on the model can be overriden by passing key-value pairs on the command line.
For example, use

   processing_profile_name="example profile"

to have the resulting model be defined using <example profile> instead of the processing profile
assigned to the source model.  If named (rather than positional) arguments are used, "--model-overrides" must precede each key-value pair.

The copy command only copies the definitions.  It does not copy any underlying model data.

EOS
}


sub execute {
    my $self = shift;
   
    # TODO: put all non-user-interface elements of this into a method on the model and have this call it
    $DB::single = 1;

    my $src_model = $self->from; 
    
    my $model_class = $src_model->class;
    $self->status_message("Source model class is a " . $src_model->class ."\n");
    $model_class =~ m/Model::(.*?)$/;
    my $define_cmd_class_name = "Genome::Model::Command::Define::" . $1;
        
    my $cmd_class_object = $define_cmd_class_name->get_class_object;
    my @cmd_props = $define_cmd_class_name->property_names;
    
    #grab the required params for the define command
    #-- ignore model name because we're passing in our own
    #-- ignore data directory for now.  we'll let it default to creating its own
    #   unless the user specifies an override, which we'll take care of later
    
    my @filtered_cmd_props =
    grep {$_ ne "data_directory" && $_ ne "model_name"}
    map {$_->property_name}
    grep {$_->{is_input}}
          map {$cmd_class_object->property_meta_for_name($_)} @cmd_props;

    my %usable_props = map {$_, 1} grep {$src_model->can($_)} @filtered_cmd_props;
        
    # these are things the command specifies and we might say on the command line
    # to pas to the model create command, but we can't ask the model for.
    my %un_usable_props = map {$_, 1} grep {!$src_model->can($_)} @filtered_cmd_props;
    
    my %cmd_params;
    for my $property (keys %usable_props) {
        if (defined $src_model->$property) {
            $cmd_params{$property} = $src_model->$property;
        } 
    }
    
    # grab overridden properties and overlay them on top of the
    # parameters from the original model
    my %property_overrides = $self->_parse_overrides;

    # Make sure that if either processing_profile_name or processing_profile_id
    # are specified in overrides that we override both of those in the params...
    if (defined $property_overrides{'processing_profile_name'} || $property_overrides{'processing_profile_id'}) {
        $cmd_params{'processing_profile_name'} = undef;
        $cmd_params{'processing_profile_id'} = undef;
    }

    # ask the model if there's anything else we need to copy 
    %cmd_params = (%cmd_params, $src_model->additional_params_for_copy); 

    for my $key (%property_overrides) {
        # allow overriding data directory on the copy and pass that in
        unless ($key eq "data_directory") {
            next if (!exists ($cmd_params{$key}) && !exists $un_usable_props{$key});
        }
        
        $cmd_params{$key} = $property_overrides{$key};
    }
    
    $cmd_params{'model_name'} = $self->to;
   
    # kick off the command to build it
    my $define_cmd = $define_cmd_class_name->create(%cmd_params);
    my $define_res = $define_cmd->execute();
    unless ($define_res) {
        $self->error_message(
            "Error defining new model:" . $define_cmd->error_message
            . "\nParams were: " . Data::Dumper::Dumper(\%cmd_params));
        return;
    }
    
    # grab our new model from the command output
    my $new_model = Genome::Model->get($define_cmd->result_model_id);
    
    
    # assign all the instrument data from the original model to the new one
    

    unless ($self->skip_instrument_data_assignments ) {
        my @idas = $src_model->instrument_data_assignments;
        my @instrument_data = Genome::InstrumentData->get(id=>[map {$_->instrument_data_id} @idas]);

        for (@instrument_data) {
               my $assign_cmd = Genome::Model::Command::InstrumentData::Assign->create(model_id=>$new_model->id,
                                                                                 instrument_data_id=>$_->id);
               unless ($assign_cmd->execute) {
                    $self->error_message("Couldn't assign instrument data id " . $_->id);
                    return;
               }
        }
    }

    my @inputs_to_copy = $src_model->inputs_necessary_for_copy;
    for (@inputs_to_copy) {
        unless(Genome::Model::Input->create(value_class_name=>$_->value_class_name,
                                            value_id=>$_->value_id,
                                            name=>$_->name,
                                            model_id=>$new_model->id)) {
            $self->error_message(sprintf("Couldn't copy model input %s with value %s to the new model", $_->name, $_->value_id));
            return;
        }
    }

    $self->_copied_model($new_model);

    return 1;
}

#
# read in parameters passed in the form of key=value
#

sub _check_dependent_properties {
    my ($self, $class, %overrides) = @_;
    my %dependency_problems;
    for my $prop (keys %overrides) {
        my @deps = $class->dependent_properties($prop);
        my @unset = grep { !exists $overrides{$_} } @deps;
        if (@unset) {
            $dependency_problems{$prop} = \@unset;
            $self->warning_message("Changing property $prop affects the following properties which were not updated:\n\t" . join("\n\t", @unset));
        }
    }
    
}

sub _parse_overrides {
    my $self = shift;
    my @bare_args = $self->model_overrides;
    
    my %overrides = ();
    
    for (@bare_args) {
        if (m/(.*?)=(.*)/) {
            #print "$1 $2\n";
            $overrides{$1} = $2;
        } else {
            $self->warning_message("Unable to process $_ as a property override, skipping");
        }
        
    }

    return %overrides;
}


1;
