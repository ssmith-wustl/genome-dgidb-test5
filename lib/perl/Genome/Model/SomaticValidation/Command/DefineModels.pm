package Genome::Model::SomaticValidation::Command::DefineModels;

use strict;
use warnings;

use Genome;

class Genome::Model::SomaticValidation::Command::DefineModels {
    is => 'Genome::Command::Base',
    has_input => [
        somatic_build => {
            is => 'Genome::Model::Build::Somatic',
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
        auto_build => {
            is => 'Boolean',
            default_value => 1,
            doc => 'Whether or not the somatic validation model will build automatically upon completion of the underlying reference alignment models',
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
genome model somatic-validation define-models --variant-list variants --tumor-subject H_KU-12345-1 --normal-subject H_KU-12345-2 --region-of-interest-set validation_capture_set --target-region-set-name validation_capture_set
EOS
}

sub help_detail {                           # this is what the user will see with the longer version of help. <---
    return <<EOS 
    Creates two reference alignment models, one for each of the subjects provided, and creates a somatic validation model based on the two.
EOS
}

sub execute {
    my $self = shift;

    #setup a soft default--copy target region to region of interest
    unless($self->region_of_interest_set) {
        $self->region_of_interest_set($self->target_region_set);
    }

    my $variant_list = $self->_check_inputs;
    return unless $variant_list;

    my $somatic_build = $self->somatic_build;

    my $tumor_model_id = $self->_create_reference_alignment_model($somatic_build->tumor_build->model->subject);
    my $tumor_model = Genome::Model->get($tumor_model_id);
    return unless $tumor_model;

    my $normal_model_id = $self->_create_reference_alignment_model($somatic_build->normal_build->model->subject);
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
        auto_build_alignments => $self->auto_build,
        processing_profile_id => $processing_profile->id,
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

sub _create_reference_alignment_model {
    my $self = shift;
    my $subject = shift;

    my $target_region_set = $self->target_region_set;
    my $region_of_interest_set = $self->region_of_interest_set;
    my $processing_profile = $self->reference_alignment_processing_profile;
    my $reference_sequence_build = $region_of_interest_set->reference;

    my $define_cmd = Genome::Model::Command::Define::ReferenceAlignment->create(
        subject => $subject,
        target_region_set_names => [$target_region_set->name],
        region_of_interest_set_name => $region_of_interest_set->name,
        auto_assign_inst_data => $self->auto_assign_instrument_data,
        auto_build_alignments => $self->auto_build,
        processing_profile_id => $processing_profile->id,
        reference_sequence_build => $reference_sequence_build->id,
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

sub _check_inputs {
    my $self = shift;

    #Reference sequences of ROI and variant list need to match
    my $region_of_interest_set = $self->region_of_interest_set;
    my $somatic_build = $self->somatic_build;

    my @variant_list = Genome::FeatureList->get(subject => $somatic_build);
    unless(scalar @variant_list) {
        $self->error_message('No variant list has been entered into the system for this somatic build.');
        return;
    }

    if(scalar @variant_list > 1) {
        while (scalar @variant_list > 1) {
            $self->status_message('Found multiple variant lists for the specified Somatic model.');
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

    unless($region_of_interest_set->reference eq $variant_list->reference) {
        $self->error_message(
            'Reference sequence for region of interest set, ' . $region_of_interest_set->reference->__display_name__ .
            ', does not match that of the variant list, ' . $variant_list->reference->__display_name__ . '.',
        );
        return;
    }

    return $variant_list;
}

1;
