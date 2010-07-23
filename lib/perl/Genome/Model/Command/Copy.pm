package Genome::Model::Command::Copy;

use strict;
use warnings;

use Genome;

require Genome::Utility::FileSystem;


class Genome::Model::Command::Copy {
    class_name => __PACKAGE__,    
    is => 'Genome::Command::OO',
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
  schema_name => 'Main',
};

sub sub_command_sort_position { 2 }

sub help_brief {
    return <<"EOS"
create a new genome model based on an existing one
EOS
}

sub help_synopsis {
    return <<"EOS"
    genome model copy --from 123456789 --to "copy_of_my_model" --model-overrides 
    processing_profile_name="use this processing profile instead"
    or
    genome model copy 123456789 "copy_of_my_model" 
    processing_profile_name="use this processing profile instead"   
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
assigned to the source model.

The copy command only copies the definitions.  It does not copy any underlying model data.

EOS
}


sub execute {
    
    my $self = shift;
    
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
    
    my @usable_props =
    grep {$_ ne "data_directory" && $_ ne "model_name"}
    map {$_->property_name}
    grep {$_->{is_input}}
          map {$cmd_class_object->property_meta_for_name($_)} @cmd_props;
    
    my %cmd_params = map {$_, $src_model->$_} @usable_props;

    # This is a complete and total hack for copying somatic models
    # I'd like to make this something smarter or more generic, but that is an order of magnitude more trouble
    if ($define_cmd_class_name eq "Genome::Model::Command::Define::Somatic") {
        $cmd_params{'tumor_model_id'} = $src_model->tumor_model->id;
        $cmd_params{'normal_model_id'} = $src_model->normal_model->id;
    }    
    
    # grab overridden properties and overlay them on top of the
    # parameters from the original model
    my %property_overrides = $self->_parse_overrides;
    for my $key (%property_overrides) {
        # allow overriding data directory on the copy and pass that in
        unless ($key eq "data_directory") {
            next if (!exists ($cmd_params{$key}));
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
    
    my @instrument_data = $src_model->instrument_data;

    unless ($self->skip_instrument_data_assignments ) {
        for (@instrument_data) {
               my $assign_cmd = Genome::Model::Command::InstrumentData::Assign->create(model_id=>$new_model->id,
                                                                                 instrument_data_id=>$_->id);
               unless ($assign_cmd->execute) {
                    $self->error_message("Couldn't assign instrument data id " . $_->id);
                    return;
               }
        }
    }

    return 1;
}

#
# read in parameters passed in the form of key=value
#

sub _parse_overrides {
    my $self = shift;
    my @bare_args = $self->model_overrides;
    
    my %overrides = ();
    
    for (@bare_args) {
        if (m/(.*?)=(.*)/) {
            print "$1 $2\n";
            $overrides{$1} = $2;
        } else {
            $self->warning_message("Unable to process $_ as a property override, skipping");
        }
        
    }
    
    return %overrides;
}


1;
