
package Genome::Model::Command::Create::Model;

use strict;
use warnings;

use Genome;
use Command; 
use Genome::Model;
use File::Path;
use Data::Dumper;

class Genome::Model::Command::Create::Model {
    is => ['Genome::Model::Event'],
    sub_classification_method_name => 'class',
    has => [
        #TODO: make processing_profile not a parameter, name only.
        processing_profile          => { is => 'Genome::ProcessingProfile', doc => 'Not used as a parameter', id_by => 'processing_profile_id', is_optional => 1, },
        processing_profile_name     => { is => 'varchar', len => 255,  doc => 'The name of the processing profile to be used. '},
        model_name                  => { is => 'varchar', len => 255, doc => 'User-meaningful name for this model' },
        sample                      => { is => 'varchar', len => 255, doc => 'The name of the sample all the reads originate from' },
        model                       => { is => 'Genome::Model', is_optional => 1, id_by => 'model_id', doc => 'Not used as a parameter' },
        instrument_data             => { is => 'String', doc => 'The instrument data for this model', is_optional => 1, is_transient =>1 },
    ],
    schema_name => 'Main',
};

sub _shell_args_property_meta {
    # exclude this class' commands from shell arguments
    return grep { 
            $_->property_name ne 'model_id'
            #not ($_->via and $_->via ne 'run') && not ($_->property_name eq 'run_id')
        } shift->SUPER::_shell_args_property_meta(@_);
}


sub sub_command_sort_position {
    1
}

sub help_brief {
    "create a new genome model"
}

sub help_synopsis {
    return <<"EOS"
genome-model create
                    --model-name test5
                    --sample ley_aml_patient1_tumor
                    --processing-profile-name nature_aml_08
EOS
}

sub help_detail {
    return <<"EOS"
This defines a new genome model.
The properties of the model determine what will happen when the add-reads command is run.

Define the processing profile to be used by name. Do not specify the
processing_profile_id as this will be looked up and overridden by the processing
profile name.

To obtain a list of available processing profiles, use genome-model list
processing-profiles.
EOS
}

sub target_class{
    return "Genome::Model";
}

sub command_properties{
    my $self = shift;
    
    return
        grep { $_ ne 'id' and $_ ne 'bare_args'}         
            map { $_->property_name }
                $self->_shell_args_property_meta;
}

sub execute {
    my $self = shift;

    $DB::single = $DB::stopper;

    unless ($self->_get_processing_profile_from_name()) { 
        $self->event_status('Failed');
        $self->error_message("Error: Expecting 1 processing profile match." );
        return;
    }

    $self->_validate_execute_params();

    $self->_add_instrument_data();
    
    # generic: abstract out
    my %params = %{ $self->_extract_command_properties_and_duplicate_keys_for__name_properties() };
    
    my $obj = $self->_create_target_class_instance_and_error_check( \%params );
    unless ($obj) {
        $self->error_message("Failed to create model!");
        return;
    }

    if (my @problems = $obj->invalid) {
        $self->error_message("Invalid model!");
        $obj->delete;
        return;
    }
    
    $self->status_message("created model " . $obj->name);
    print $obj->pretty_print_text,"\n";
    
    unless ($self->_build_model_filesystem_paths($obj)) {
        $self->error_message('filesystem path creation failed');
        $obj->delete;
        return;
    }
   
    $self->result($obj);

    return $obj;
}

sub _build_model_filesystem_paths {
    my $self = shift;
    my $model = shift;
    
    my $base_dir = $model->data_directory;
    
    eval {mkpath("$base_dir");};
    
    if ($@) {
        $self->error_message("model base dir $base_dir could not be successfully created");
        return;
    }
    
    return 1;
    
}

sub _extract_command_properties_and_duplicate_keys_for__name_properties{
    my $self = shift;
    
    my $target_class = $self->target_class; 
    my %params;
    
    for my $command_property ($self->command_properties) {
        my $value = $self->$command_property;
        next unless defined $value;

        # This is an ugly hack just for creating Genome::Model objects
        # Command-derived objects gobble up the --name parameter as part of the
        # UR framework initialization, so we're stepping around that by
        # knowing that Genome::Model's have names, and the related Command
        # param is called "model_name"
        if ($command_property eq 'model_name') {
            if ($target_class->can('name')) {
                $params{'name'} = $value;
            }
        } else {
            # processing_profile_name is only used to grab the processing_profile... so dont include it as a param
            unless ($command_property eq 'processing_profile_name') { 
                my $object_property = $command_property;
                if ($target_class->can($command_property . "_name")) {
                    $object_property .= "_name";
                }
                $params{$object_property} = $value;
            }
        }
    }
    
    return \%params;
}

sub _validate_execute_params{
    my $self = shift;

    if (my @args = @{ $self->bare_args }) {
        $self->error_message("extra arguments: @args");
        $self->usage_message($self->help_usage);
        return;
    }
}

sub _create_target_class_instance_and_error_check{
    my ($self, $params_in) = @_;
    
    my %params = %{$params_in};
    
    my $target_class = $self->target_class;    
    my $target_class_meta = $target_class->get_class_object; 
    my $type_name = $target_class_meta->type_name;
    
    $self->set(
        date_scheduled  => $self->_time_now(),
        date_completed  => undef,
        event_status    => 'Scheduled',
        event_type      => $self->command_name,
        lsf_job_id      => undef, 
        user_name       => $ENV{USER}, 
    );

    my $obj = $target_class->create(%params);
    if (!$obj) {
        $self->error_message(
            "Error creating $type_name: " 
            . $target_class->error_message
        );
        return;
    }

    $self->model($obj);

    if (my @problems = $obj->invalid) {
        $self->error_message("Error creating $type_name:\n\t"
            . join("\n\t", map { $_->desc } @problems)
            . "\n");
        $obj->delete;
        return;
    }   

    $self->date_completed($self->_time_now());
    unless($obj) {
        $self->event_status('Failed');
        $self->error_message("Failed to create genome model: " . $obj->error_message);
        print Dumper(\%params);
        return;
    }
    
    $self->event_status('Succeeded');
    return $obj;
}

# Retreives the processing profile matching the name specified
sub _get_processing_profile_from_name {
    my $self = shift;
    my $processing_profile_name = $self->processing_profile_name;
    my @processing_profiles = Genome::ProcessingProfile->get(name => $processing_profile_name);

    # Bomb out unless exactly 1 matching processing profile is found
    my $num_processing_profiles = scalar(@processing_profiles);
    unless($num_processing_profiles == 1) {
        return 0;
    }

    my $pp = $processing_profiles[0];
    $self->processing_profile_id($pp->id);
    return $pp->id; 
}

# Adds the instrument data as an input on the creation event
sub _add_instrument_data {
    my $self = shift;

    my $instrument_data = $self->instrument_data;

    unless ($instrument_data) {
        return;
    }

    $self->add_input(name => 'instrument_data', value => $instrument_data);

    return 1;
}

1;

