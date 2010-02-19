package Genome::Model::Build::Convergence;

use strict;
use warnings;

use Genome;

class Genome::Model::Build::Convergence {
    is => 'Genome::Model::Build',
    has => [
        members => {
            is => 'Genome::Model::Build',
            via => 'inputs',
            is_mutable => 1,
            is_many => 1,
            where => [ name => 'member' ],
            to => 'value',
            doc => 'The builds for the models assigned to this Convergence model when the build was created.'
        },
    ],
};

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);

    unless ($self) {
        return;
    }
   
    my $model = $self->model;
    unless ($model) {
        $self->error_message("Failed to get a model for this build!");
        return;
    }

    my @member_models = $model->members;
    unless (scalar @member_models) {
        $self->error_message("No member models found!");
        return;
    }
    
    $self->_assign_members;
    
    return $self;
}

sub _assign_members {
    my $self = shift;
    
    #Shouldn't do this more than once
    return 1 if $self->members;
    
    my @member_models = $self->model->members;
    
    for my $member_model (@member_models) {
        my $last_succeeded_build = $member_model->last_succeeded_build;
        unless($last_succeeded_build) {
            $self->status_message('Skipping model ' . $member_model->id . ' (' . $member_model->name . ') with no succeeded builds.');
            next;
        }
        
        $self->status_message('Adding build ' . $last_succeeded_build->id . ' to convergence build.');
        $self->add_member( $last_succeeded_build );
    }
    
    return 1;
}

sub calculate_estimated_kb_usage {
    my $self = shift;

    #TODO Use 1 MB for now--up this value when a build generates more than just a report
    return 1024;
}

1;
