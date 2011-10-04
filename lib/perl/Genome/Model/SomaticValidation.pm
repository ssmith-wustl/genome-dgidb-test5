package Genome::Model::SomaticValidation;

use strict;
use warnings;

use Genome;

class Genome::Model::SomaticValidation {
    is  => 'Genome::Model',
    has => [
        #FIXME probably remove this and fix the (potentional) report issue by having it look at model but fallback on processing profile
        map({
            $_ => {
                via => 'processing_profile',
            }
        } Genome::ProcessingProfile::SomaticValidation->params_for_class),
    ],
    has_optional => [
        # TODO these should be DV2 results not FeatureLists
        snv_variant_list => {
            is => 'Genome::FeatureList',
            via => 'inputs', to => 'value', where => [ name => 'snv_variant_list' ],
            is_mutable => 1,
        },
        indel_variant_list => {
            is => 'Genome::FeatureList',
            via => 'inputs', to => 'value', where => [ name => 'indel_variant_list' ],
            is_mutable => 1,
        },
        sv_variant_list => {
            is => 'Genome::FeatureList',
            via => 'inputs', to => 'value', where => [ name => 'sv_variant_list' ],
            is_mutable => 1,
        },
        reference_sequence_build => {
            is => 'Genome::Model::Build::ReferenceSequence',
            via => 'inputs', to => 'value', where => [ name => 'reference_sequence_build' ],
            is_mutable => 1,
        },
        tumor_reference_alignment => {
            is => 'Genome::Model::ReferenceAlignment',
            via => 'inputs', to => 'value', where => [ name => 'tumor_reference_alignment' ],
            is_mutable => 1,
        },
        normal_reference_alignment => {
            is => 'Genome::Model::ReferenceAlignment',
            via => 'inputs', to => 'value', where => [ name => 'normal_reference_alignment' ],
            is_mutable => 1,
        },
    ],
};

sub _validate_required_for_start_properties {
    my $self = shift;

    my @missing_required_properties;
    push @missing_required_properties, '*_variant_list' unless ($self->snv_variant_list || $self->indel_variant_list || $self->sv_variant_list);
    push @missing_required_properties, 'reference_sequence_build' unless ($self->reference_sequence_build);
    push @missing_required_properties, 'tumor_reference_alignment' unless ($self->tumor_reference_alignment);
    push @missing_required_properties, 'normal_reference_alignment' unless ($self->normal_reference_alignment);

    my $tag;
    if (@missing_required_properties) {
        $tag = UR::Object::Tag->create(
            type => 'error',
            properties => \@missing_required_properties,
            desc => 'missing required property',
        );
    }

    return $tag;
}

sub _validate_subjects {
    my $self = shift;

    my $primary_subject = $self->subject;
    return unless $primary_subject;

    my @inputs = $self->inputs;
    my @subject_mismatches;
    for my $input (@inputs) {
        my $object = $input->value;
        next unless $object; #this is reported in validate_inputs_have_values

        next unless $object->can('subject');

        my $object_subject = $object->subject;
        next unless $object_subject and $object_subject->can('source'); #only want to test that samples come from same place (still hacky)

        #FIXME hacky
        unless($object_subject->source->id eq $primary_subject->id) {
            push @subject_mismatches, $input->name;
        }
    }

    my $tag;
    if (@subject_mismatches) {
        $tag = UR::Object::Tag->create(
            type => 'error',
            properties => \@subject_mismatches,
            desc => "subject does not match build's subject (" . $primary_subject->__display_name__ . ")",
        );
    }

    return $tag;
}

1;
