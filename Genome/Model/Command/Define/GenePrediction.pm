# FIXME josborne
#  Long: all the things that are wrong with teh define::somatic are probably wrong with this
package Genome::Model::Command::Define::GenePrediction;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Define::GenePrediction {
    is => 'Genome::Model::Command::Define',
    has => [
        assembly_model => { 
            is => 'Genome::Model',
            id_by => 'assembly_model_id', 
            doc => 'imported assembly model to get assembly from',
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
  --assembly-model 54321
  --data-directory /gscmnt/somedisk/somedir/model_dir
EOS
}

sub help_detail {
    return <<"EOS"
This defines a new genome model representing gene prediction.
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

#    unless(defined $self->assembly_model) {
#        $self->error_message("Could not get a model for normal model id: " . $self->normal_model_id);
#        return;
#    }


    # run Genome::Model::Command::Define execute
    my $super = $self->super_can('_execute_body');
    $super->($self,@_);

    # get the model created by the super
    my $model = Genome::Model->get($self->result_model_id);

    # Link this somatic model to the normal and tumor models  
    $model->add_from_model(from_model => $self->assembly_model, role => 'assembly_model');

    return 1;
}

1;
