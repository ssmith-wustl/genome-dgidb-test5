# FIXME ebelter
#  Long: remove this and all define modeuls to have just one that can handle model inputs
package Genome::Model::Command::Define::SomaticCapture;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Define::SomaticCapture {
    is => 'Genome::Model::Command::Define',
    has => [
        tumor_model => { 
            is => 'Genome::Model',
            id_by => 'tumor_model_id', 
            doc => 'The tumor model id being analyzed' 
        },
        normal_model => { 
            is => 'Genome::Model', 
            id_by => 'normal_model_id', 
            doc => 'The normal model id being analyzed' 
        },
        data_directory => {
            is => 'Text',
            len => 255,
            doc => 'Optional parameter representing the data directory the model should use. Will use a default if none specified.'
        },
        subject_name => {
            is => 'Text',
            len => 255,
            doc => 'The name of the subject all the reads originate from',
        },
    ],
    has_optional => [
        model_name => {
            is => 'Text',
            len => 255,
            doc => 'User meaningful name for this model (default value: $SUBJECT_NAME.$PP_NAME)'
        },
        subject_type => {
            is => 'Text',
            len => 255,
            doc => 'The type of subject all the reads originate from, defaults to sample_name',
            default => 'sample_group',
        },
        processing_profile_name => {
            is => 'Text',
            doc => 'identifies the processing profile by name',
            default => 'default',
        },

   ],
};

sub help_synopsis {
    return <<"EOS"
genome model define 
  --subject_name ovc2
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

sub execute {
    my $self = shift;

    $DB::single=1;
#    $self->SUPER::execute(@_) or return;

    unless(defined $self->normal_model) {
        $self->error_message("Could not get a model for normal model id: " . $self->normal_model_id);
        return;
    }
    unless(defined $self->tumor_model) {
        $self->error_message("Could not get a model for tumor model id: " . $self->tumor_model_id);
        return;
    }

    #Set up the "subject" of the model
    my $tumor_subject = $self->tumor_model->subject;
    my $normal_subject = $self->normal_model->subject;

    if(($tumor_subject->can('source') || $tumor_subject->can('sample')) and ($normal_subject->can('source') || $normal_subject->can('sample'))) {
        
        my $tumor_source;
        if($tumor_subject->can('source')) {
            $tumor_source = $tumor_subject->source; 
        } else {
            $tumor_source = $tumor_subject->sample->source;
        }
        
        my $normal_source;
        if($normal_subject->can('source')) {
            $normal_source = $normal_subject->source; 
        } else {
            $normal_source = $normal_subject->sample->source;
        }
        
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

    # run Genome::Model::Command::Define execute
    my $super = $self->super_can('_execute_body');
    $super->($self,@_);

    # get the model created by the super
    my $model = Genome::Model->get($self->result_model_id);

    # Link this somatic model to the normal and tumor models  
    $model->add_from_model(from_model => $self->normal_model, role => 'normal');
    $model->add_from_model(from_model => $self->tumor_model, role => 'tumor');

    return 1;
}

1;
