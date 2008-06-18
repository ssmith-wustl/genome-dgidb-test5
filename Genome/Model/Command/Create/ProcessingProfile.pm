
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
    my %property_to_subclass = $self->get_subclass_hash;
    
    # for each key in the subclass hash, if the processing profile has that
    # property, check to make sure the module exists that was specified
    for my $key (keys %property_to_subclass) {
        my $package = $property_to_subclass{$key};
        
        # Do some string processing to contatinate the subclass property value
        # onto the end of the parent class's path. 
        # ex. Genome::Model::Command::AddReads with a subclass property value of
        # 'maq' becomes Genome::Model::Command::AddReads::Maq
        my $subclass_property_value;
        unless ($subclass_property_value = 
                    $self->resolve_module_by_subclassing_property($package)) {
            $self->error_message(
                "Could not resolve module by subclassing property");
            return undef;                        
        }    
        
        my @subclass_parts = map { ucfirst } split(' ', $subclass_property_value);
                        $subclass_property_value = join('', @subclass_parts);
        my $subclass_name = join('::', "$package" ,
                        $subclass_property_value);
       
        # Check to see if the package exists
        eval "require $subclass_name";
        if ($@) {
            $self->error_message(
                "No package with name $subclass_name found for property $key");
            return undef;                        
        }     
    }

    return 1;
}

# Return the module that should be used for the subclassing property
sub resolve_module_by_subclassing_property {
    my($self, $package) = @_;

    # Which property on the model will tell is the proper subclass to call?
    unless ($package->can('command_subclassing_model_property')) {
        $self->error_message("class $package did not implement command_subclassing_model_property()");
        return;
    }
    my $subclassing_property = $package->command_subclassing_model_property();

    # Check for properties called both "foo" and "foo_name"
    unless ($self->can($subclassing_property)) {
        if ($subclassing_property =~ "_name") {
            my @subclass_parts = split('_', $subclassing_property);
            pop @subclass_parts;
            $subclassing_property = join ('_', @subclass_parts);
        }
        else {
            $self->error_message("class $self command_subclassing_model_property() returned $subclassing_property, but that is not a property of a model");
            return undef;
        }

        unless ($self->can($subclassing_property)) {
            $self->error_message("class $self command_subclassing_model_property() returned $subclassing_property, but that is not a property of a model");
            return undef;
        }
    }

    my $value = $self->$subclassing_property;
    if ($value =~ m/^maq/) {
        return 'maq';
    } else {
        return $value;
    }

}

# Returns a hardcoded hash where the keys are the properties a processing
# profile has that we are verifying and the values are the associated module 
sub get_subclass_hash {
    my $self = shift;
    my $addreads = "Genome::Model::Command::AddReads";

    # read_calibrator currently not implemented, so not included 
    # Sequencing platform not currently verified
    my %property_to_subclass = (genotyper              => "$addreads" . "::UpdateGenotype",
                                indel_finder           => "$addreads" . "::FindVariations",
                                read_aligner           => "$addreads" . "::AlignReads",
                                # sequencing_platform    => "$addreads" . "::AssignRun",
                               );
                        
    return %property_to_subclass;                    
}

1;

