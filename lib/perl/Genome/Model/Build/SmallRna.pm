package Genome::Model::Build::SmallRna;

use strict;
use warnings;

use Genome;
use File::Basename;

class Genome::Model::Build::SmallRna {
    is => 'Genome::Model::Build',
    has => [
        ref_model => {
            is => 'Genome::Model::ReferenceAlignment',
            via => 'model',
        },
        ref_build_id => {
            is => 'Text',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'ref_build', value_class_name => 'Genome::Model::Build::ReferenceAlignment' ],
            is_mutable => 1,
        },
        ref_build => {
            is => 'Genome::Model::Build::ReferenceAlignment',
            id_by => 'ref_build_id',
        },
   ],
};


sub create {
    my $class = shift;

   
    my $bx = $class->define_boolexpr(@_);
    my $model_id = $bx->value_for('model_id');
    my $model = Genome::Model->get($model_id);
    $model->update_build_inputs;

    my $self = $class->SUPER::create(@_);

    unless ($self) {
        return;
    }
    
    $model = $self->model;
    unless ($model) {
        $self->error_message("Failed to get a model for this build!");
        return;
    }

    my $ref_model = $model->ref_model;
    unless ($ref_model) {
        $self->error_message("Failed to get a ref_model!");
        return;
    }
    
    
  #  my $ref_build = $self->ref_build;
  my $ref_build =  $ref_model->last_succeeded_build;
unless ($ref_build) {
        $self->error_message("Failed to get a ref build!");
        return;
    }

    return $self;
}


sub bam_file {
    my $self = shift;
  #  my $ref_build = $self->ref_build;
    my $ref_model = $self->ref_model;
    my $ref_build =  $ref_model->last_succeeded_build;
   
    my $bam_file = $ref_build->whole_rmdup_bam_file;
    unless ($bam_file){
        die $self->error_message("No whole_rmdup_bam file found for ref build!");
    }
    return $bam_file;
}


sub workflow_instances {
    my $self = shift;
    my @instances = Workflow::Operation::Instance->get(
        name => $self->workflow_name
    );

    #older builds used a wrapper workflow
    unless(scalar @instances) {
        return $self->SUPER::workflow_instances;
    }

    return @instances;
}

sub workflow_name {
    my $self = shift;
    return $self->build_id . ' SmallRna Downstream Analysis Pipeline';
}



1;
