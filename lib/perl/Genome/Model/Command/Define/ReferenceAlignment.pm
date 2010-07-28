package Genome::Model::Command::Define::ReferenceAlignment;

use strict;
use warnings;

use Genome;
use Mail::Sender;

class Genome::Model::Command::Define::ReferenceAlignment {
    is => 'Genome::Model::Command::Define',
    has => [
        reference_sequence_build => {
            doc => 'ID or name of the reference sequence to align against',
            default_value => 'NCBI-human-build36',
        },
        target_region_set_names => {
            is => 'Text',
            is_optional => 1,
            is_many => 1,
            doc => 'limit the model to take specific capture or PCR instrument data'
        },
        region_of_interest_set_name => {
            is => 'Text',
            is_optional => 1,
            doc => 'limit coverage and variant detection to within these regions of interest'
        }
    ]
};

sub type_specific_parameters_for_create {
    my $self = shift;

    my $reference_sequence_build = $self->reference_sequence_build;

    my @params = ();

    #Cheap trick:
    #If was called programmatically the actual build might be passed instead of text to retrieve it
    # notably `genome model copy` does this internally
    #Otherwise, the user passed in a string that we need to use to find the build
    if(ref $reference_sequence_build) {
        push @params,
            reference_sequence_build => $reference_sequence_build;
    } else {
        push @params,
            reference_sequence_name => $reference_sequence_build;
    }

    return @params;
}

sub execute {
    my $self = shift;
    
    my $result = $self->SUPER::_execute_body(@_);
    return unless $result;

    my $model = Genome::Model->get($self->result_model_id);
    unless ($model) {
        $self->error_message("No model generated for " . $self->result_model_id);
        return;
    }

    # LIMS is preparing actual tables for these in the dw, until then we just manage the names.
    my @target_region_set_names = $self->target_region_set_names;
    if (@target_region_set_names) {
        for my $name (@target_region_set_names) {
            my $i = $model->add_input(value_class_name => 'UR::Value', value_id => $name, name => 'target_region_set_name');
            if ($i) {
                $self->status_message("Modeling instrument-data from target region '$name'");
            }
            else {
                $self->error_message("Failed to add target '$name'!");
                $model->delete;
                return;
            }
        }
    }
    else {
        $self->status_message("Modeling whole-genome (non-targeted) sequence.");
    }
    if ($self->region_of_interest_set_name) {
        my $name = $self->region_of_interest_set_name;
        my $i = $model->add_input(value_class_name => 'UR::Value', value_id => $name, name => 'region_of_interest_set_name');
        if ($i) {
            $self->status_message("Analysis limited to region of interest set '$name'");
        }
        else {
            $self->error_message("Failed to add region of interest set '$name'!");
            $model->delete;
            return;
        }
    } else {
        $self->status_message("Analyzing whole-genome (non-targeted) reference.");
    }

    return $result;
}

1;
