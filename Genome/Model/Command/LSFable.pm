package Genome::Model::Command::LSFable;

use strict;
use warnings;

use UR;
use Command; 

# A class other command classes can inherit from that contains
# helper methods for LSF-related stuff

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Command',
    is_abstract => 1,
);

sub lsf_job_id {
my($self) = @_;

    return $ENV{'LSB_JOBID'};
}

sub create_or_get_event_by_jobid {
my($self) = @_;

    my $event;

    my $jobid = $self->lsf_job_id();
    if ($jobid) {
        $event = Genome::Model::Event->get(lsf_job_id => $jobid);
    }

    unless ($event) {
        my %params = %{ $self->_assemble_event_creation_params($jobid) };

        $event = Genome::Model::Event->create(%params);
    }
    return $event;
}

sub _get_genome_model{
    my $self = shift;
    
    my $model = Genome::Model->get(name => $self->model);
    unless ($model) {
        $self->error_message("Can't find information about genome model named ".$self->model );
        return undef;
    }
    
    return $model;
}

sub _assemble_event_creation_params{
    my ($self, $jobid) = @_;
    
    my $model = $self->_get_genome_model();
    
    my %params = ( event_type => $self->get_class_object->class_name,
                       genome_model_id => $model->id,
                       date_scheduled => scalar(localtime),
                       user_name => $ENV{'USER'},
                     );
    if ($jobid) {
        $params{'lsf_job_id'} = $jobid;
    }
        
    return \%params;
}

1;


