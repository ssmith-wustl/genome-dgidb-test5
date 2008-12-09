package Genome::Model::Command::Build::Assembly;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::Assembly {
    is => 'Genome::Model::Command::Build',
    has => [
        ],
 };

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    
    my $model = $self->model;

    my @read_sets = $model->read_sets;

    unless (scalar(@read_sets) && ref($read_sets[0])  &&  $read_sets[0]->isa('Genome::Model::ReadSet')) {
        $self->error_message('No read sets have been added to model: '. $model->name);
        $self->error_message("The following command will add all available read sets:\ngenome-model add-reads --model-id=".
        $model->id .' --all');
        return;
    }
    
    return $self;
}

sub sub_command_sort_position { 40 }

sub help_brief {
    "assemble a genome"
}

sub help_synopsis {
    return <<"EOS"
genome-model build mymodel 
EOS
}

sub help_detail {
    return <<"EOS"
One build of a given assembly model.
EOS
}

sub stages {
    my @stages = qw/
        setup_project
        assemble
        verify_successful_completion
    /;
    return @stages;
}

sub setup_project_job_classes {
    my @classes = qw/
            Genome::Model::Command::Build::Assembly::AssignReadSetToModel
            Genome::Model::Command::Build::Assembly::FilterReadSet
            Genome::Model::Command::Build::Assembly::TrimReadSet
            Genome::Model::Command::Build::Assembly::AddReadSetToProject
    /;
    return @classes;
}

sub assemble_job_classes {
    my @classes = qw/
            Genome::Model::Command::Build::Assembly::Assemble
    /;
    return @classes;
}

sub verify_successful_completion_job_classes {
    my @classes = qw/
            Genome::Model::Command::Build::VerifySuccessfulCompletion
    /;
    return @classes;
}

sub setup_project_objects {
    my $self = shift;
    return $self->model->unbuilt_read_sets;
}

sub assemble_objects {
    my $self = shift;
    return 1;
}

sub verify_successful_completion_objects {
    my $self = shift;
    return 1;
}

sub _get_sub_command_class_name{
  return __PACKAGE__;
}

1;

