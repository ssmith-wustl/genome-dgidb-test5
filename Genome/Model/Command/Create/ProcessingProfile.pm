
package Genome::Model::Command::Create::ProcessingProfile;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Create::ProcessingProfile {
    is => 'Command',
    has => [
        type_name                    => { is => 'VARCHAR2', len => 255, is_optional => 1, 
                                          doc => "The type of processing profile. Not required unless creating a generic 'processing profile'. "},
        profile_name                 => { is => 'VARCHAR2', len => 255, is_optional => 0 ,
                                          doc => 'The human readable name for the processing profile'},
        copy_from                    => { is => 'Genome::ProcessingProfile', is_optional => 1, id_by => 'copy_from_name',
                                          doc => 'Copy this profile, and modify the specified properties.' },
    ],
};

sub help_brief {
    "creation of new processing profiles"
}

sub help_detail {
    return <<"EOS"
This defines a new processing profile.

The properties of the processing profile determine what will happen when the add-reads command is run.
EOS
}

sub sub_command_sort_position { 1 }

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    if (my $copy_from = $self->copy_from) {
        my $copy_from_name = $self->copy_from_name;
        $self->status_message("checking $copy_from_name settings...");
        for my $property_name ($self->get_class_object->all_property_names) {
            my $value = $copy_from->$property_name;
            if (defined $value and $self->can($property_name) and not defined $self->$property_name) {
                $self->status_message("setting $property_name to '$value' from $copy_from_name");
                $self->$property_name($value);
            }
        }
    }
    return $self;
}

# Ensures that all properties from the property_to_subclass hash are existing modules
sub verify_params {
    my $self = shift;
    my %subclass_property_to_possible_values
        = $self->get_subclass_property_to_possible_values_hash();

    # for each property that we can check for, check if the processing profile
    # has that property and verify that it can be handled
    for my $key (keys %subclass_property_to_possible_values) {
        # If the command has a property named "foo" instead of "foo_name" check
        # that instead
        my $command_accessor = $key;
        unless ($self->can($command_accessor)) {
            if ($command_accessor =~ "_name") {
                my @subclass_parts = split('_', $command_accessor);
                pop @subclass_parts;
                $command_accessor = join ('_', @subclass_parts);
            }
        }    
        
        # Check the property of the command
        if ($self->can($command_accessor)) {
            my $pp_subclassing_property_value; 
            
            # Should we fail out here or simply not validate a parameter that is
            # not supplied?
            unless((defined($self->$command_accessor))&&($self->$command_accessor ne "")) {
                next;
            }

            # Special case for maq which usually comes as "maq-0-6-5" or the
            # like... we just use the Maq.pm module for all maq versions
            if ($self->$command_accessor =~ m/^maq/) {
                $pp_subclassing_property_value = 'Maq';
            # Otherwise just take the property and capitalize it
            } else {
                my @subclass_parts = map { ucfirst } split(' ', $self->$command_accessor);
                $pp_subclassing_property_value = join(' ', @subclass_parts);
            }
            
            my $subclass_name =
                $subclass_property_to_possible_values{$key}{$pp_subclassing_property_value};
            
            # Bomb out since we have gotten a parameter that cannot be resolved
            # to a module
            unless(defined($subclass_name)) {
                $self->error_message(
                    "No package could be resolved for value $subclass_name for property $command_accessor");
                return undef;                        
            }
            
            # Check to see if the package exists
            eval "require $subclass_name";
            if ($@) {
                $self->error_message(
                    "No package with name $subclass_name found for property $key");
                return undef;                        
            }
        }
    }
        
    return 1;
}

# TODO: add in postprocess sub command classes equivilant
# For all possible subclasses of addreads 
sub get_subclass_property_to_possible_values_hash {
    my $self = shift;
    my @addreads_subclasses = 
        Genome::Model::Command::AddReads->get_sub_command_classes();
    
    # Build a hash of hashes to map each of the subclassing properties to their
    # possible values and the class associated
    # Ex. subclassing property      value       associated class
    #       read_aligner_name       Maq       G::M::C::AddReads::AlignReads::Maq
    #                               Mosaik      ""                  ""::Mosaik
    #                               etc         etc     
    my %subclass_property_to_possible_values;
    for my $subclass (@addreads_subclasses) {
        # skip PLQA for now... it and align reads both use the read_aligner
        # property... so dont let it overwrite align reads hash entry
        if ($subclass =~ m/ProcessLowQualityAlignments/) {
            next;
        }
    
        # get the subclassing property for this class
        my $subclassing_property = $subclass->command_subclassing_model_property();
        # map that class's value-to-subclass hash to this subclassing property
        $subclass_property_to_possible_values{$subclassing_property} =
            $self->get_subclassing_value_to_subclass_hash($subclass);
    }

    return %subclass_property_to_possible_values; 
}

# For a given class, return all possible subclassing values mapped to the
# subclass they would use
sub get_subclassing_value_to_subclass_hash {
    my $self = shift;
    my $target_class = shift;
    
    # Get the hash from the target class that maps the possible parameter values
    # to the subclass associated with it
    # Ex.   value       associated class
    #       Maq         G::M::C::AddReads::AlignReads::Maq
    #       Mosaik      ""                         ""::Mosaik
    #       etc         etc     
    my %subclassing_value_to_subclass =
        $target_class->_sub_command_name_to_class_name_map();
                        
    return \%subclassing_value_to_subclass;                    
}

sub command_properties{
    my $self = shift;
    
    return
        grep { $_ ne 'id' and $_ ne 'bare_args'}         
            map { $_->property_name }
                $self->_shell_args_property_meta;
}

sub _extract_command_properties_and_duplicate_keys_for__name_properties{
    my $self = shift;
    
    my $target_class = $self->target_class; 
    my %params;
    
    for my $command_property ($self->command_properties) {
        my $value = $self->$command_property;
        next unless defined $value;

        # This is an ugly hack just for creating Genome::ProcessingProfile objects
        # Command-derived objects gobble up the --name parameter as part of the
        # UR framework initialization, so we're stepping around that by
        # knowing that Genome::ProcessingProfile's have names, and the related Command
        # param is called "profile_name"
        if ($command_property eq 'profile_name') {
            if ($target_class->can('name')) {
                $params{'name'} = $value; 
            }
        } else {
            my $object_property = $command_property;
            if ($target_class->can($command_property . "_name")) {
                $object_property .= "_name";
            }
           	$params{$object_property} = $value;
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

    return 1;
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

    # Check to see if the processing profile exists before creating
    # First, enforce the name being unique since processing profiles are
    # specified by name
    my @existing_profiles = $self->target_class->get(name => $params{name});
    if (scalar(@existing_profiles) > 0) {
        my $existing_name = $existing_profiles[0]->name;
        $self->error_message("A processing profile named $existing_name already exists. Processing profile names must be unique.");
        return;
    }


    # Now, enforce functional uniqueness. We dont want more than one processing
    # profile doing effectively the same thing.
    my %get_params = %params;
    # exclude 'name' and 'id' from the get since these parameters would make the
    # processing_profile unique despite being effectively the same as another...
    delete $get_params{name};
    delete $get_params{id};

    # If any params exist besides name and id... check them
    if (scalar(keys %get_params) > 0) {
        @existing_profiles = $self->target_class->get_with_special_parameters(%get_params);
        if (scalar(@existing_profiles) > 0) {
            my $existing_name = $existing_profiles[0]->name;
            $self->error_message("A processing profile named $existing_name already exists with the same parameters. Processing profiles must be functionally unique.");
            return;
        }
    }

    # If it passed the above checks, create the processing profile
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



1;

