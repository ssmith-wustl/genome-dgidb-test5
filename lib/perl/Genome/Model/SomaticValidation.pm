package Genome::Model::SomaticValidation;

use strict;
use warnings;

use Genome;

class Genome::Model::SomaticValidation {
    is  => 'Genome::Model',
    has => [
        map({
            $_ => {
                via => 'processing_profile',
            }
        } Genome::ProcessingProfile::SomaticValidation->params_for_class),
    ],
    has_optional => [
        reference_sequence_build => {
            is => 'Genome::Model::Build::ImportedReferenceSequence',
            via => 'variant_list', to => 'reference',
        },
        tumor_model_links => {
            is => 'Genome::Model::Link', reverse_as => 'to_model', where => [ role => 'tumor'], is_many => 1, doc => ''
        },
        tumor_model => {
            is => 'Genome::Model', via => 'tumor_model_links', to => 'from_model', doc => '',
        },
        tumor_model_id => {
            is => 'Integer', via => 'tumor_model', to => 'id',
        },
        normal_model_links => {
            is => 'Genome::Model::Link', reverse_as => 'to_model', where => [ role => 'normal'], is_many => 1, doc => ''
        },
        normal_model => {
            is => 'Genome::Model', via => 'normal_model_links', to => 'from_model', doc => '',
        },
        normal_model_id => {
            is => 'Integer', via => 'normal_model', to => 'id',
        },
        variant_list_file => {
            is => 'Text',
            via => 'variant_list', to => 'file_path',
        },
        variant_list => {
            is => 'Genome::FeatureList',
            id_by => 'variant_list_id',
        },
        variant_list_id => {
            is => 'Text',
            via => 'inputs', to => 'value_id', where => [value_class_name => 'Genome::FeatureList', name => 'variant_list'],
            is_many => 0,
            is_mutable => 1,
        }
    ],
};

sub create {
    my $class = shift;
    my %params = @_;

    my $tumor_model_id = delete $params{tumor_model_id};
    my $tumor_model = delete $params{tumor_model};
    my $normal_model_id = delete $params{normal_model_id};
    my $normal_model = delete $params{normal_model};

    unless($tumor_model) {
        $tumor_model = Genome::Model->get($tumor_model_id);

        unless($tumor_model) {
            $class->error_message('Could not find tumor model.' );
            return;
        }
    }

    unless($normal_model) {
        $normal_model = Genome::Model->get($normal_model_id);

        unless($normal_model) {
            $class->error_message('Could not find normal model.');
            return;
        }
    }

    my $tumor_subject = $tumor_model->subject;
    my $normal_subject = $normal_model->subject;

    if($tumor_subject->can('source') and $normal_subject->can('source')) {
        my $tumor_source = $tumor_subject->source;
        my $normal_source = $normal_subject->source;

        if($tumor_source eq $normal_source) {
            my $subject = $tumor_source;

            #Set up other parameters for call to parent execute()
            $params{subject_id} = $subject->id;
            $params{subject_class_name} = $subject->class;
        } else {
            $class->error_message('Tumor and normal samples are not from same source!');
            return;
        }
    } else {
        $class->error_message('Unexpected subject for tumor or normal model!');
        return;
    }

    my $normal_reference = $normal_model->reference_sequence_build;
    my $tumor_reference = $tumor_model->reference_sequence_build;

    unless($normal_reference eq $tumor_reference) {
        $class->error_message('Tumor and normal reference alignment models do not have the same reference sequence!');
        return;
    }

    if(exists $params{variant_list}) {
        my $variant_list_reference = $params{variant_list}->reference;

        unless($normal_reference eq $variant_list_reference) {
            $class->error_message('Reference alignment models and variant list do not have the same reference sequence!');
            return;
        }
    }

    my $self = $class->SUPER::create(%params);

    $self->add_from_model(from_model => $normal_model, role => 'normal');
    $self->add_from_model(from_model => $tumor_model, role => 'tumor');

    return $self;
}

1;
