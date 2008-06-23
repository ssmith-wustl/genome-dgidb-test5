
package Genome::Model::Command::Create::ProcessingProfile;

use strict;
use warnings;

use above "Genome";

class Genome::Model::Command::Create::ProcessingProfile {
    is => 'Genome::Model::Command',
};

sub help_brief {
    "creation of new processing profiles"
}

sub sub_command_sort_position { 1 }

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

1;

