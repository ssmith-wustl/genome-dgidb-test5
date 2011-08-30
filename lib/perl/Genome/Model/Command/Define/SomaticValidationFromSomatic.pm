#FIXME should move any non UI->API logic into the model's class
package Genome::Model::Command::Define::SomaticValidationFromSomatic;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Define::SomaticValidationFromSomatic {
    is => 'Genome::Command::Base',
    has_input => [
        somatic_build => {
            is => 'Genome::Model::Build', #TODO Ideally this should work: ['Genome::Model::Build::Somatic', 'Genome::Model::Build::SomaticVariation'],
            doc => 'The original Somatic build for which validation is being done',
        },
        target_region_set => {
            is => 'Genome::FeatureList',
            doc => 'The target-region-set for the reference alignment models for the samples',
        },
    ],
    has_optional_input => [
        assign_existing_instrument_data => {
            is => 'Boolean',
            default_value => 1,
            doc => 'If instrument data already exists matching the sample and target region set, assign it to the newly created reference alignment models.',
        },
        auto_assign_instrument_data => {
            is => 'Boolean',
            default_value => 1,
            doc => 'Whether or not new instrument data will be automatically assigned to the reference alignment models',
        },
        region_of_interest_set => {
            is => 'Genome::FeatureList',
            doc => 'The region-of-interest for the reference alignment models for the samples (defaults to target_region_set)',
        },
        reference_alignment_processing_profile => {
            is => 'Genome::ProcessingProfile::ReferenceAlignment',
            doc => 'The processing profile to use for the reference alignment models',
            default_value => '', #FIXME fill this in
        },
        somatic_validation_processing_profile => {
            is => 'Genome::ProcessingProfile::SomaticValidation',
            doc => 'The processing profile to use for the somatic validation model.',
            default_value => '', #FIXME fill this in
        }
    ],
};

sub help_brief {
    "Create the models for doing validation of somatic variants"
}

sub help_synopsis {
    return <<EOS
genome model define somatic-validation-from-somatic --variant-list variants --tumor-subject H_KU-12345-1 --normal-subject H_KU-12345-2 --target-region-set-name validation_capture_set
EOS
}

sub help_detail {
    return <<EOS
    Creates two reference alignment models, one for each of the subjects provided, and creates a somatic validation model based on the two.
EOS
}

sub execute {
    my $self = shift;

    #verify correct build subclass (remove once TODO above is satisfied)
    my $somatic_build = $self->somatic_build;
    unless($somatic_build->isa('Genome::Model::Build::Somatic') or
           $somatic_build->isa('Genome::Model::Build::SomaticVariation')) {
        $self->error_message('--somatic-build must be a somatic or somatic-variation build, not a ' . $somatic_build->type_name);
    }

    #setup a soft default--copy target region to region of interest
    unless($self->region_of_interest_set) {
        $self->region_of_interest_set($self->target_region_set);
    }

    my $variant_list = $self->_check_inputs_and_get_variant_list;
    return unless $variant_list;

    my $tumor_model_id = $self->_get_or_create_reference_alignment_model($somatic_build->tumor_build->model->subject);
    my $tumor_model = Genome::Model->get($tumor_model_id);
    return unless $tumor_model;

    my $normal_model_id = $self->_get_or_create_reference_alignment_model($somatic_build->normal_build->model->subject);
    my $normal_model = Genome::Model->get($normal_model_id);
    unless($normal_model) {
        $tumor_model->delete;
        return;
    }

    my $processing_profile = $self->somatic_validation_processing_profile;

    my $define_cmd = Genome::Model::Command::Define::SomaticValidation->create(
        variant_list => $variant_list,
        tumor_model => $tumor_model,
        normal_model => $normal_model,
        processing_profile => $processing_profile,
    );

    unless($define_cmd->execute) {
        $self->error_message('Failed to create somatic validation model.');
        for my $m ($tumor_model, $normal_model) {
            $m->delete;
        }
        return;
    }

    return $define_cmd->result_model_id;
}

sub _get_or_create_reference_alignment_model {
    my $self = shift;
    my $subject = shift;

    my $target_region_set = $self->target_region_set;
    my $region_of_interest_set = $self->region_of_interest_set;
    my $processing_profile = $self->reference_alignment_processing_profile;
    my $reference_sequence_build = $region_of_interest_set->reference;

    my %params = (
        subject => $subject,
        region_of_interest_set_name => $region_of_interest_set->name,
        auto_assign_inst_data => $self->auto_assign_instrument_data,
        processing_profile => $processing_profile,
        reference_sequence_build => $reference_sequence_build,
    );

    my @existing_models = Genome::Model::ReferenceAlignment->get(
        %params,
        target_region_set_name => $target_region_set->name,
    );
    if(scalar @existing_models > 1) {
        while (scalar @existing_models > 1) {
            $self->status_message('Found multiple existing reference alignment models for ' . $subject->__display_name__ . '.');
            @existing_models = $self->_get_user_verification_for_param_value('reference-alignment-model', @existing_models);
        }
    }
    if(scalar @existing_models) {
        return $existing_models[0]->id;
    }

    my $define_cmd = Genome::Model::Command::Define::ReferenceAlignment->create(
        %params,
        target_region_set_names => [$target_region_set->name],
    );

    unless($define_cmd->execute and $define_cmd->result_model_id) {
        $self->error_message('Failed to create reference alignment model for ' . $subject->name);
        return;
    }

    if($self->assign_existing_instrument_data) {
        my $assign_cmd = Genome::Model::Command::InstrumentData::Assign->create(
            model_id => $define_cmd->result_model_id,
            all => 1,
        );
        unless($assign_cmd->execute) {
            my $model = Genome::Model->get($define_cmd->result_model_id);
            $model->delete;
            return;
        }
    }

    return $define_cmd->result_model_id;
}

sub _check_inputs_and_get_variant_list {
    my $self = shift;

    #Reference sequences of ROI and variant list need to match
    my $region_of_interest_set = $self->region_of_interest_set;
    my $somatic_build = $self->somatic_build;

    my @variant_list = Genome::FeatureList->get(subject => $somatic_build);
    unless(scalar @variant_list) {
        $self->error_message('No variant list has been entered into the system for this somatic build.  If one has been created, use `genome feature-list update` to set its subject to the somatic build.');
        return;
    }

    if(scalar @variant_list > 1) {
        while (scalar @variant_list > 1) {
            $self->status_message('Found multiple variant lists for the specified somatic build.');
            @variant_list = $self->_get_user_verification_for_param_value('variant-list', @variant_list);
        }
    }
    my $variant_list = $variant_list[0];

    unless($region_of_interest_set->reference) {
        $self->error_message('No reference sequence associated with the specified region of interest set: ' . $region_of_interest_set->name);
        return;
    }

    unless($variant_list->reference) {
        $self->error_message('No reference sequence associated with the specified variant list: ' . $variant_list->name);
        return;
    }

    unless($region_of_interest_set->reference->is_compatible_with($variant_list->reference)) {
        $self->error_message(
            'Reference sequence for region of interest set, ' . $region_of_interest_set->reference->__display_name__ .
            ', does not match that of the variant list, ' . $variant_list->reference->__display_name__ . '.',
        );
        return;
    }

    return $variant_list;
}

1;
