package Genome::Model::Command::Build::Assembly;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Build::Assembly {
    is => 'Genome::Model::Command::Build',
    has => [
        ],
 };

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
    return $self->model->unbuilt_instrument_data;
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

