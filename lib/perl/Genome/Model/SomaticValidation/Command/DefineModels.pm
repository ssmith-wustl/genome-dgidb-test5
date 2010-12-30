package Genome::Model::SomaticValidation::Command::DefineModels;

use strict;
use warnings;

use Genome;

class Genome::Model::SomaticValidation::Command::DefineModels {
    is => 'Genome::Command::Base',
    has_input => [
        variant_list => {
            is => 'Genome::FeatureList',
            doc => 'The list of variants to process.',
        },
        tumor_subject => {
            is => 'Genome::Sample',
            doc => 'The sample for validation data for the tumor'
        },
        normal_subject => {
            is => 'Genome::Sample',
            doc => 'The sample for validation data for the normal',
        },
        target_region_set => {
            is => 'Genome::FeatureList',
            doc => 'The target-region-set for the reference alignment models for the samples',
        },
        reference_alignment_processing_profile => {
            is => 'Genome::ProcessingProfile::ReferenceAlignment',
            doc => 'The processing profile to use for the reference alignment models',
        },
        somatic_validation_processing_profile => {
            is => 'Genome::ProcessingProfile::SomaticValidation',
            doc => 'The processing profile to use for the somatic validation model.'
        }
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

    return unless $self->_check_inputs;

    my $tumor_model_id = $self->_create_reference_alignment_model($self->tumor_subject);
    my $tumor_model = Genome::Model->get($tumor_model_id);
    return unless $tumor_model;

    my $normal_model_id = $self->_create_reference_alignment_model($self->normal_subject);
    my $normal_model = Genome::Model->get($normal_model_id);
    unless($normal_model) {
        $tumor_model->delete;
        return;
    }

    my $processing_profile = $self->somatic_validation_processing_profile;

    my $define_cmd = Genome::Model::Command::Define::SomaticValidation->create(
        variant_list => $self->variant_list,
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
        subject_name => $subject->name,
        subject_id => $subject->id,
        subject_class_name => $subject->class,
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
    my $variant_list = $self->variant_list;

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

    #Tumor and normal subjects must come from the same source
    my $tumor_subject = $self->tumor_subject;
    my $normal_subject = $self->normal_subject;

    unless($tumor_subject->source) {
        $self->error_message('No source associated with tumor subject: ' . $tumor_subject->name);
        return;
    }

    unless($normal_subject->source) {
        $self->error_message('No source associated with normal subject: ' . $normal_subject->name);
        return;
    }

    unless($tumor_subject->source eq $normal_subject->source) {
        $self->error_message(
            'Source of tumor subject, ' . $tumor_subject->source->__display_name__ .
            ', does not match that of the normal subject,' . $normal_subject->source->__display_name__ . '.'
        );
        return;
    }

    return 1;
}

1;
