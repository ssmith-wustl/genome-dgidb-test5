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
        my $last_succeeded_build = $member_model->last_complete_build;
        unless($last_succeeded_build) {
            $self->status_message('Skipping model ' . $member_model->id . ' (' . $member_model->name . ') with no succeeded builds.');
            next;
        }
        
        $self->status_message('Adding build ' . $last_succeeded_build->id . ' to convergence build.');
        $self->add_member( $last_succeeded_build );
    }
    
    return 1;
}

sub all_subbuilds_closure {
    my $self = shift;
    my @initial_subbuilds = @_;
    
    unless(scalar @initial_subbuilds) {
        @initial_subbuilds = $self->members;
    }

    my $seen = {}; #Track which subbuilds are already processed
    
    return map($self->_all_subbuilds_helper($_, $seen), @initial_subbuilds);
}

sub _all_subbuilds_helper {
    my $self = shift;
    my $subbuild = shift;
    my $seen = shift;
    
    return if $seen->{$subbuild->id}; #Already processed previously
    
    $seen->{$subbuild->id}++;
    
    my $type = $subbuild->type_name;
    
    my @subbuilds_to_process;

    if ($type eq 'convergence') {
        push @subbuilds_to_process,
            $subbuild->members;

    } else {
        push @subbuilds_to_process,
            $subbuild->from_builds;
    }

    return $subbuild, map($self->_all_subbuilds_helper($_, $seen), @subbuilds_to_process);
}

sub calculate_estimated_kb_usage {
    my $self = shift;

    #TODO Use 1 MB for now--up this value when a build generates more than just a report
    return 1024;
}

sub workflow_name {
    my $self = shift;
    return $self->build_id . ' Convergence';
}

1;
