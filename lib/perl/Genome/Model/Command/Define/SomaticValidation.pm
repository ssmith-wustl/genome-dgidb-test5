package Genome::Model::Command::Define::SomaticValidation;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Define::SomaticValidation {
    is => 'Genome::Model::Command::Define::Helper',
    has => [
        variant_list => {
            is => 'Genome::FeatureList', id_by => 'variant_list_id',
        },
        variant_list_id => {
             is => 'Text', implied_by => 'variant_list', is_input => 1,
        },
        tumor_model => { 
            is => 'Genome::Model',
            id_by => 'tumor_model_id', 
            doc => 'The tumor model id being analyzed',
            is_input => 1,
        },
        tumor_model_id => {
            is => 'Integer',
            is_input => 1,
        },
        normal_model => { 
            is => 'Genome::Model', 
            id_by => 'normal_model_id', 
            doc => 'The normal model id being analyzed',
            is_input => 1,
        },
        normal_model_id => {
            is => 'Integer',
            is_input => 1,
        },
        subject_name => {
            is => 'Text',
            is_input => 1,
            is_optional => 1,
            doc => 'Subject name is derived from normal and tumor models and is not necessary as input to somatic models',
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
        variant_list_id => $self->variant_list->id,
        variant_list => $self->variant_list,
        tumor_model => $self->tumor_model,
        normal_model => $self->normal_model;

    return @params;
}

sub execute {
    my $self = shift;

    unless(defined $self->normal_model) {
        $self->error_message("Could not get a model for normal model id: " . $self->normal_model_id);
        return;
    }
    unless(defined $self->tumor_model) {
        $self->error_message("Could not get a model for tumor model id: " . $self->tumor_model_id);
        return;
    }

    my $tumor_subject = $self->tumor_model->subject;
    my $normal_subject = $self->normal_model->subject;

    if($tumor_subject->can('source') and $normal_subject->can('source')) {
        my $tumor_source = $tumor_subject->source;
        my $normal_source = $normal_subject->source;
        
        if($tumor_source eq $normal_source) {
            my $subject = $tumor_source;
            
            #Set up other parameters for call to parent execute()
            $self->subject_id($subject->id);
            $self->subject_class_name($subject->class);
            $self->subject_name($subject->common_name || $subject->name);
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

    unless($normal_reference eq $tumor_reference) {
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
