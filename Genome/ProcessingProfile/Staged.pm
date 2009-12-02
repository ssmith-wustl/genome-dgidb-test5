
package Genome::ProcessingProfile::Staged;

use strict;
use warnings;

class Genome::ProcessingProfile::Staged {
    is => 'Genome::ProcessingProfile',
};

sub stages {
    my $class = shift;
    $class = ref($class) if ref($class);
    die("Please implement stages in class '$class'");
}

sub classes_for_stage {
    my $self = shift;
    my $stage_name = shift;
    my $classes_method_name = $stage_name .'_job_classes';
    #unless (defined $self->can('$classes_method_name')) {
    #    die('Please implement '. $classes_method_name .' in class '. $self->class);
    #}
    return $self->$classes_method_name;
}

sub objects_for_stage {
    my $self = shift;
    my $stage_name = shift;
    my $model = shift;
    my $objects_method_name = $stage_name .'_objects';
    #unless (defined $self->can('$objects_method_name')) {
    #    die('Please implement '. $objects_method_name .' in class '. $self->class);
    #}
    return $self->$objects_method_name($model);
}

sub verify_successful_completion_job_classes {
    my @sub_command_classes= qw/
        Genome::Model::Command::Build::VerifySuccessfulCompletion
    /;
    return @sub_command_classes;
}

sub verify_successful_completion_objects {
    my $self = shift;
    return 1;
}

1;
