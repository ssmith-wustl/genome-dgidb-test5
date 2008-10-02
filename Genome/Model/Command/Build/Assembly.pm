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

sub command_subclassing_model_property {
    print "hi\n";
    'foora'
}

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
        stage1
        stage2
    /;
}

sub stage1_job_classes {
    my @stages = qw/
            Genome::Model::Command::Build::Assembly::AssignReadSetToModel
            Genome::Model::Command::Build::Assembly::FilterReadSet
            Genome::Model::Command::Build::Assembly::TrimReadSet
            Genome::Model::Command::Build::Assembly::AddReadSetToProject
    /;
    return @stages;
}

sub stage2_job_classes {
    my @stages = qw/
            Genome::Model::Command::Build::Assembly::Assemble
    /;
    return @stages;
}

sub stage1_objects {
    my $self = shift;
    return $self->model->unbuilt_read_sets;
}

sub stage2_objects {
    my $self = shift;
    return 1;
}

sub execute {
    my $self = shift;
    return $self->build_in_stages;
}

sub _get_sub_command_class_name{
  return __PACKAGE__;
}

1;

