package Genome::ProcessingProfile::Msi;
use strict;
use warnings;
use Genome;

class Genome::ProcessingProfile::Msi {
    is => 'Genome::ProcessingProfile',
    doc => "manual sequence improvement"
};

sub _initialize_model {
    my ($self,$model) = @_;
    warn "defining new model " . $model->__display_name__ . " for profile " . $self->__display_name__ . "\n";
    return 1;
}

sub _initialize_build {
    my ($self,$build) = @_;
    warn "defining new build " . $build->__display_name__ . " for profile " . $self->__display_name__ . "\n";
    return 1;
}

sub _execute_build {
    my ($self,$build) = @_;
    warn "executing build logic for " . $self->__display_name__ . ':' .  $build->__display_name__ . "\n";
    return 1;
}

1;

