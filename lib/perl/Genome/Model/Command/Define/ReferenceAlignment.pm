package Genome::Model::Command::Define::ReferenceAlignment;

use strict;
use warnings;

use Genome;

require Carp;
use Mail::Sender;
use Regexp::Common;

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
    my $reference_sequence_build = $self->_get_reference_sequence_build;
    return unless $reference_sequence_build;
    return ( reference_sequence_build => $reference_sequence_build );
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

sub _get_reference_sequence_build {
    my $self = shift;

    my $rsb_identifier = $self->reference_sequence_build;
    unless ( $rsb_identifier )  {
        Carp::confess("No reference sequence build (or name or id) given");
    }

    # We may already have it
    if ( ref($rsb_identifier) ) {
        return $rsb_identifier;
    }

    # from cmd line - this dies if non found
    local $ENV{GENOME_NO_REQUIRE_USER_VERIFY} = 1;
    my @reference_sequence_builds = Genome::Command::Base->resolve_param_value_from_text($rsb_identifier, 'Genome::Model::Build::ImportedReferenceSequence');
    if ( @reference_sequence_builds == 1 ) {
        return $reference_sequence_builds[0];
    }

    Carp::confess("Multiple imported reference sequence builds found for identifier ($rsb_identifier): ".join(', ', map { '"'.$_->__display_name__.'"' } @reference_sequence_builds ));
}

sub _get_latest_build_for_imported_reference_sequence_model_name {
    my ($self, $model_name) = @_;

    $self->status_message("Getting imported reference sequence build for model name: $model_name");

    my @models = Genome::Model::ImportedReferenceSequence->get(name => $model_name);
    if ( not @models ) {
        $self->statusr_message("No imported reference sequence models for name: $model_name");
        return;
    }
    elsif ( @models > 1 ) { 
        $self->error_message(
            'Multiple models ('.join(',', map { $_->id } @models).") for name: $model_name"
        );
        return;
    }

    my @builds = $models[0]->builds;
    if ( not @builds ) {
        $self->statusr_message("No builds for imported reference sequence model: ".$models[0]->__display_name__);
        return;
    }

    return $builds[$#builds]; # most recent, not sure if these are 'successful' or not
}

1;

