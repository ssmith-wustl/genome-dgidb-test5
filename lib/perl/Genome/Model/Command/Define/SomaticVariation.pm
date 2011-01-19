# FIXME ebelter
#  Long: remove this and all define modeuls to have just one that can handle model inputs
package Genome::Model::Command::Define::SomaticVariation;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Define::SomaticVariation {
    is => [
    'Genome::Model::Command::Define',
    'Genome::Command::Base',
    ],
    has => [
        tumor_model => {
            is => 'Genome::Model::ReferenceAlignment',
            is_input => 1,
            doc => 'Name or id of tumor model being analyzed',
        },
        normal_model => {
            is => 'Genome::Model::ReferenceAlignment',
            is_input => 1,
            doc => 'Name or id of normal model being analyzed',
        },
        previous_variants_build => {
            is => 'Genome::Model::Build::ImportedVariantList',
            is_input => 1, 
            doc => 'Id of imported variants build to screen somatic variants against',
        },
        annotation_build => {
            is => 'Genome::Model::Build::ImportedAnnotation',
            is_input => 1, 
            doc => 'Id of annotation build to use for fast tiering of variants',
        },
    ],
};

sub help_synopsis {
    return <<"EOS"
genome model define 
  --tumor-id 12345
  --normal-id 54321
  --data-directory /gscmnt/somedisk/somedir/model_dir
EOS
}

sub help_detail {
    return <<"EOS"
This defines a new genome model representing the somatic analysis between a normal and tumor model.
EOS
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    return $self;
}

sub type_specific_parameters_for_create {
    my $self = shift;

    my @params = ();

    push @params,(
        tumor_model => $self->tumor_model,
        normal_model => $self->normal_model,
        annotation_build => $self->annotation_build,
        previous_variants_build => $self->previous_variants_build
    );


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
    unless(defined $self->annotation_build) {
        $self->error_message("Could not get a build for annotation build id: " . $self->annotation_build_id);
        return;
    }
    unless(defined $self->previous_variants_build) {
        $self->error_message("Could not get a build for previous variants build id: " . $self->previous_variants_build_id);
        return;
    }

    my $tumor_subject = $self->tumor_model->subject;
    my $normal_subject = $self->normal_model->subject;

    if($tumor_subject->can('source') and $normal_subject->can('source')) {

        my $tumor_source = $tumor_subject->source;
        my $normal_source = $normal_subject->source;
        
        unless ($tumor_source eq $normal_source) {
            $self->error_message("Tumor model and normal model samples do not come from the same individual.  Tumor ". $tumor_source->common_name .", Normal ". $normal_source->subject_name);
        }
        $self->subject_id($tumor_subject->id);
        $self->subject_class_name($tumor_subject->class);
        $self->subject_name($tumor_subject->common_name || $tumor_subject->name);
    
    } else {
        $self->error_message('Unexpected subject for tumor or normal model!');
        return;
    }

    # run Genome::Model::Command::Define execute
    my $super = $self->super_can('_execute_body');
    return $super->($self,@_);
}

1;
