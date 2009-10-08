package Genome::Model::Command::Build::VerifySuccessfulCompletion;

use strict;
use warnings;

use Data::Dumper;
use Genome;

class Genome::Model::Command::Build::VerifySuccessfulCompletion {
    is => ['Genome::Model::Event'],
    has_optional => [
        force_abandon => {
            is => 'Boolean',
            default_value => 0,
            doc => 'A flag to force abandon of failed events(default=0)',
        },
    ],
    doc => 'verify that a given build has completed successfully',
};

sub sub_command_sort_position { 6 }

sub help_detail {
    "This module will update the status of a current running build";
}

sub execute {
    my $self = shift;
    my $model = $self->model;
    unless ($self->build_id) {
        unless ($model->current_running_build_id) {
            $self->error_message('Current running build id not found for model '. $model->name .'('. $model->id .')');
            return;
        }
        $self->build_id($model->current_running_build_id);
    }
    my $build = $self->build;
    unless ($build) {
        $self->error_message('No build found with id '. $self->build_id);
        return;
    }
    my $build_event = $build->build_event;
    unless ($build_event) {
        $self->error_message('Build event not found for model '.
                             $self->model_id .' and build '. $self->build_id);
        return;
    }
    if ($build_event->verify_successful_completion($self->force_abandon)) {
        my $disk_allocation = $build->disk_allocation;
        if ($disk_allocation) {
            my $reallocate = Genome::Disk::Allocation::Command::Reallocate->execute( allocator_id => $disk_allocation->allocator_id);
            unless ($reallocate) {
                $self->warning_message('Failed to reallocate disk space.');
            }
        }
        #$build_event->event_status('Succeeded');
        #$build_event->date_completed(UR::Time->now);
        $self->event_status('Succeeded');
        $self->date_completed(UR::Time->now);
        #$model->current_running_build_id(undef);
        #$model->last_complete_build_id($build_event->build_id);
        
        # shall we clean up old builds?
        if (defined $model->keep_n_most_recent_builds) {
            my $handle_build_evisceration = sub {
                $self->eviscerate_old_builds_for_this_model();
            };
            $self->create_subscription(method => 'commit', callback => $handle_build_evisceration);
        }
        
    } else {
        #$build_event->event_status('Failed');
        #$build_event->date_completed(UR::Time->now);
        $self->event_status('Failed');
        $self->date_completed(UR::Time->now);
    }
    return 1;
}

sub eviscerate_old_builds_for_this_model {
    my $self = shift;
    my $subscription = shift;
    my $model = $self->build->model;
    my $this_build = $self->build;
    
    # a couple guards here, to make sure we don't run by accident
    # don't run on failed builds or models that ask to be eviscerated!
    return if ($self->event_status ne 'Succeeded');
    
    unless (defined $model->keep_n_most_recent_builds) {
        return;
    }
    
    my $recent_keep_count = $model->keep_n_most_recent_builds;

    # The calling build will not have been marked as succeeded yet, so allow an "or" here to catch our own build
    my @builds = sort {$a->build_id <=> $b->build_id}
        grep {$_->can('eviscerate')}
        grep {$_->build_status eq "Succeeded" || $_->id == $self->build->id} 
        $model->builds;
        
    my @builds_to_eviscerate = splice @builds, 0, scalar @builds - $recent_keep_count;
    
    for my $doomed_build (@builds_to_eviscerate) {
        next if (!$doomed_build->can('eviscerate'));
        my $resource_lock_name = $doomed_build->accumulated_alignments_directory . '.eviscerate';
        my $lock = Genome::Utility::FileSystem->lock_resource(resource_lock => $resource_lock_name, max_try => 2);
        print Dumper($lock);
        unless ($lock) {
            $self->status_message("This build is locked by another eviscerate process");
            $lock = $self->lock_resource(resource_lock => $resource_lock_name);
            unless ($lock) {
                $self->error_message("Failed to get a build lock to eviscerate!  Skipping this build.");
                next;
            }
        }
        
        $doomed_build->eviscerate;        
        
        Genome::Utility::FileSystem->unlock_resource(resource_lock=>$lock);
    }
}


1;

