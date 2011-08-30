package Genome::Model::Command::Define::SomaticValidation;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Define::SomaticValidation {
    is => 'Genome::Model::Command::Define::Helper',
    has_input => [
        variant_list => {
            is => 'Genome::FeatureList',
            doc => 'the list of variants to validate',
        },
        tumor_model => {
            is => 'Genome::Model',
            doc => 'The tumor model being analyzed',
        },
        normal_model => {
            is => 'Genome::Model',
            doc => 'The normal model id being analyzed',
        },
   ],
   has_transient_optional_input => [
        subject => {
            is => 'Text',
            doc => 'Subject is derived from normal and tumor models and is not necessary as input to somatic-validation models',
        },
        reference_sequence_build => {
            is => 'Genome::Model::Build::ReferenceSequence',
            doc => 'Reference sequence build is derived from normal and tumor models',
        },
    ],
};

sub help_detail {
    return <<"EOS"
This defines a new genome model representing the validation of somatic analysis between a normal and tumor model.
EOS
}

sub type_specific_parameters_for_create {
    my $self = shift;

    my @params = ();

    push @params,
        variant_list => $self->variant_list,
        tumor_reference_alignment => $self->tumor_model,
        normal_reference_alignment => $self->normal_model,
        reference_sequence_build => $self->reference_sequence_build;

    return @params;
}

sub execute {
    my $self = shift;

    my $tumor_subject = $self->tumor_model->subject;
    my $normal_subject = $self->normal_model->subject;

    if($tumor_subject->can('source') and $normal_subject->can('source')) {
        my $tumor_source = $tumor_subject->source;
        my $normal_source = $normal_subject->source;

        if($tumor_source eq $normal_source) {
            my $subject = $tumor_source;

            #Set up other parameters for call to parent execute()
            $self->subject($subject);
        } else {
            $self->error_message('Tumor and normal samples are not from same source!');
            return;
        }
    } else {
        $self->error_message('Unexpected subject for tumor or normal model!');
        return;
    }

    my $normal_reference = $self->normal_model->reference_sequence_build;
    my $tumor_reference = $self->tumor_model->reference_sequence_build;

    if($normal_reference eq $tumor_reference) {
        $self->reference_sequence_build($tumor_reference);
    } else {
        $self->error_message('Tumor and normal reference alignment models do not have the same reference sequence!');
        return;
    }

    my $variant_list_reference = $self->variant_list->reference;

    unless($normal_reference eq $variant_list_reference) {
        $self->error_message('Reference alignment models and variant list do not have the same reference sequence!');
        return;
    }

    # run Genome::Model::Command::Define execute
    my $super = $self->super_can('_execute_body');
    return $super->($self,@_);
}

1;
