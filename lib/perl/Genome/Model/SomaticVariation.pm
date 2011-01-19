package Genome::Model::SomaticVariation;
#:adukes short term, keep_n_most_recent_builds shouldn't have to be overridden like this here.  If this kind of default behavior is acceptable, it belongs in the base class

use strict;
use warnings;

use Genome;

class Genome::Model::Somatic {
    is  => 'Genome::Model',
    has => [
        snv_detection_strategy => {
            is => 'Text',
            via => 'processing_profile',
        },
        sv_detection_strategy => {
            is => 'Text',
            via => 'processing_profile',
        },
        indel_detection_strategy => {
            is => 'Text',
            via => 'processing_profile',
        },
        tumor_model_id => {
            is => 'Text',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'tumor_model', value_class_name => 'Genome::Model::ReferenceAlignment' ],
            is_many => 0,
            is_mutable => 0,
            is_optional => 0,
            doc => 'tumor model for somatic analysis'
        },
        tumor_model => {
            is => 'Genome::Model::ReferenceAlignment',
            id_by => 'tumor_model_id',
        },
        normal_model_id => {
            is => 'Text',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'normal_model', value_class_name => 'Genome::Model::ReferenceAlignment' ],
            is_many => 0,
            is_mutable => 0,
            is_optional => 0,
            doc => 'normal model for somatic analysis'
        },
        normal_model => {
            is => 'Genome::Model::ReferenceAlignment',
            id_by => 'normal_model_id',
        },
        annotation_build_id => {
            is => 'Text',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'annotation_build', value_class_name => 'Genome::Model::Build::ImportedAnnotation' ],
            is_many => 0,
            is_mutable => 0,
            is_optional => 0,
            doc => 'annotation build for fast tiering'
        },
        annotation_build => {
            is => 'Genome::Model::Build::ImportedAnnotation',
            id_by => 'annotation_build_id',
        },
        previous_variants_build_id => {
            is => 'Text',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'previous_variants', value_class_name => "Genome::Model::Build::ImportedVariationList"],
            is_many => 0,
            is_mutable => 0,
            is_optional => 0,
            doc => 'previous variants genome feature set to screen somatic mutations against',
        },
        previous_variants_build => {
            is => 'Genome::Model::Build::ImportedVariationList',
            id_by => 'previous_variants_build_id',
        },
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
    
    my $self = $class->SUPER::create(%params);
    
    $self->add_from_model(from_model => $normal_model, role => 'normal');
    $self->add_from_model(from_model => $tumor_model, role => 'tumor');

    return $self;
}

1;
