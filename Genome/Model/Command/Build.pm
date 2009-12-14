package Genome::Model::Command::Build;

use strict;
use warnings;

use Genome;
use Data::Dumper;

class Genome::Model::Command::Build {
    is => 'Genome::Model::Event',
    doc => "build a defined model with currently assigned inputs",
    has => [
        data_directory => { via => 'build' },
    ],
};

# Why is this here? "Build" is both a noun and a verb.
# "genome model build list" ends up getting routed here as Genome::Model::Command::Build takes precedence.
# redirect that into the right place.
# -ben

sub clean {
    my $self=shift;
    my @events = Genome::Model::Event->get(parent_event_id=>$self->id);
    for my $event (@events) {
        $event->delete;
    }
    if ($self->model->current_running_build_id == $self->id) {
        $self->model->current_running_build_id(undef);
    }
    if ($self->model->last_complete_build_id == $self->id) {
        $self->model->last_complete_build_id(undef);
    }
    $self->delete;
    return;
}

sub resolve_stage_name_for_class {
    my $self = shift;
    my $class = shift;
    my $pp = $self->model->processing_profile;
    for my $stage_name ($pp->stages) {
        my $found_class = grep { $class =~ /^$_/ } $pp->classes_for_stage($stage_name);
        if ($found_class) {
            return $stage_name;
        }
    }
    my $error_message = "No class found for '$class' in build ". $self->class ." stages:\n";
    for my $stage_name ($pp->stages) {
        $error_message .= $stage_name ."\n";
        for my $class ($pp->classes_for_stage($stage_name)) {
            $error_message .= "\t". $class ."\n";
        }
    }
    $self->error_message($error_message);
    return;
}

sub events_for_stage {
    my $self = shift;
    my $stage_name = shift;
    my $pp = $self->model->processing_profile;
    my @events;
    for my $class ($pp->classes_for_stage($stage_name)) {
        push @events, $self->events_for_class($class);
    }
    return @events;
}

sub events_for_class {
    my $self = shift;
    my $class = shift;

    my @class_events = $class->get(
                                   model_id => $self->model_id,
                                   build_id => $self->build_id,
                               );

    #Not sure if every class is supposed to have return of events
    #but adding the line below makes the tests pass for now
    return unless @class_events;

    my @sorted_class_events;
    if ($class_events[0]->id =~ /^-/) {
        @sorted_class_events = sort {$b->id <=> $a->id} @class_events;
    } else {
        @sorted_class_events = sort {$a->id <=> $b->id} @class_events;
    }
    return @sorted_class_events;
}

sub abandon_incomplete_events_for_stage {
    my $self = shift;
    my $stage_name = shift;
    my $force_flag = shift;

    my @stage_events = $self->events_for_stage($stage_name);
    my @incomplete_events = grep { $_->event_status !~ /Succeeded|Abandoned/ } @stage_events;
    if (@incomplete_events) {
        my $status_message = 'Found '. scalar(@incomplete_events) ." incomplete events for stage $stage_name:\n";
        for (@incomplete_events) {
            $status_message .= $_->id ."\t". $_->event_type ."\t". $_->event_status ."\n";
        }
        $self->status_message($status_message);
        unless (defined $force_flag) {
            my $response_1 = $self->_ask_user_question('Would you like to abandon the incomplete events?');
            if ($response_1 eq 'yes') {
                my $response_2 = $self->_ask_user_question('None of the data associated with these events will be included in further processing.  Are you sure?');
                if ($response_2 eq 'yes') {
                    for my $incomplete_event (@incomplete_events) {
                        unless ($incomplete_event->abandon) {
                            $self->error_message('Failed to abandon event '. $incomplete_event->id);
                            return;
                        }
                    }
                    return 1;
                }
            }
            # we have incomplete events but do not want to abandon
            return;
        } else {
            if ($force_flag == 1) {
                for my $incomplete_event (@incomplete_events) {
                    unless ($incomplete_event->abandon) {
                        $self->error_message('Failed to abandon event '. $incomplete_event->id);
                        return;
                    }
                }
                return 1;
            } elsif ($force_flag == 0) {
                return;
            } else {
                $self->error_messge('Illegal value '. $force_flag .' for abandon force flag.');
            }
        }
    }
    # we have no incomplete events for stage
    return 1;
}

sub continue_with_abandoned_events_for_stage {
    my $self = shift;
    my $stage_name = shift;
    my $force_flag = shift;
    
    my @stage_events = $self->events_for_stage($stage_name);
    my @abandoned_events = grep { $_->event_status eq 'Abandoned' } @stage_events;
    if (@abandoned_events) {
        my $status_message = 'Found '. scalar(@abandoned_events) ." abandoned events for stage $stage_name:\n";
        for (@abandoned_events) {
            $status_message .= $_->id ."\t". $_->event_type ."\t". $_->event_status ."\n";
        }
        $self->status_message($status_message);
        unless (defined($force_flag)) {
            my $response = $self->_ask_user_question('Would you like to continue with build, ignoring these abandoned events?');
            if ($response eq 'yes') {
                return 1;
            }
            return;
        } else {
            if ($force_flag == 1) {
                return 1;
            } elsif ($force_flag == 0) {
                return;
            } else {
                $self->error_messge('Illegal value '. $force_flag .' for continuing with abandoned force flag.');
            }
        }
    }
    return 1;
}

sub ignore_unverified_events_for_stage {
    my $self = shift;
    my $stage_name = shift;
    my $force_flag = shift;
    
    my @stage_events = $self->events_for_stage($stage_name);
    my @succeeded_events = grep { $_->event_status eq 'Succeeded' } @stage_events;
    my @can_not_verify_events = grep { !$_->can('verify_successful_completion') } @succeeded_events;
    if (@can_not_verify_events) {
        my $status_message = 'Found '. scalar(@can_not_verify_events) ." events that will not be verified:\n";
        for (@can_not_verify_events) {
            $status_message .= $_->id ."\t". $_->event_type ."\t". $_->event_status ."\n";
        }
        $self->status_message($status_message);
        unless (defined($force_flag)) {
            my $response = $self->_ask_user_question('Would you like to continue, ignoring unverified events?');
            if ($response eq 'yes') {
                return 1;
            }
            return;
        } else {
            if ($force_flag == 1) {
                return 1;
            } elsif ($force_flag == 0) {
                return;
            } else {
                $self->error_messge('Illegal value '. $force_flag .' for continuing with unverified events.');
            }
        }
    }
    return 1;
}

sub verify_successful_completion_for_stage {
    my $self = shift;
    my $stage_name = shift;
    my $force_flag = shift;

    my @stage_events = $self->events_for_stage($stage_name);
    my @succeeded_events = grep { $_->event_status eq 'Succeeded' } @stage_events;
    my @verifiable_events = grep { $_->can('verify_successful_completion') } @succeeded_events;
    my @unverified_events = grep { !$_->verify_successful_completion } @verifiable_events;
    if (@unverified_events) {
        my $status_message = 'Found '. scalar(@unverified_events) ." events that can not be verified successful:\n";
        for (@unverified_events) {
            $status_message .= $_->id ."\t". $_->event_type ."\t". $_->event_status ."\n";
        }
        $self->status_message($status_message);
        unless (defined($force_flag)) {
            my $response_1 = $self->_ask_user_question('Would you like to abandon events which failed to verify?');
            if ($response_1 eq 'yes') {
                my $response_2 = $self->_ask_user_question('Abandoning these events will exclued all data associated with these events from further analysis.  Are you sure?');
                if ($response_2 eq 'yes') {
                    for my $unverified_event (@unverified_events) {
                        unless ($unverified_event->abandon) {
                            $self->error_message('Failed to abandon event '. $unverified_event->id);
                            return;
                        }
                    }
                    return 1;
                }
            }
            return;
        } else {
            if ($force_flag == 1) {
                for my $unverified_event (@unverified_events) {
                    unless ($unverified_event->abandon) {
                        $self->error_message('Failed to abandon event '. $unverified_event->id);
                        return;
                    }
                }
                return 1;
            } elsif ($force_flag == 0) {
                return;
            } else {
                $self->error_messge('Illegal value '. $force_flag .' for continuing with unsuccessful events.');
            }
        }
    }
    return 1;
}

sub verify_successful_completion {
    my $self = shift;
    my $force_flag = shift;

    my $pp = $self->model->processing_profile;
    for my $stage_name ($pp->stages) {
        if ($stage_name eq 'verify_successful_completion') {
            last;
        }
        unless ($self->verify_successful_completion_for_stage($stage_name,$force_flag)) {
            $self->error_message('Failed to verify successful completion of stage '. $stage_name);
            return;
        }
    }
    return 1;
}

sub update_build_state {
    my $self = shift;
    my $force_flag = shift;
    my $pp = $self->model->processing_profile;
    for my $stage_name ($pp->stages) {
        if ($stage_name eq 'verify_successful_completion') {
            last;
        }
        unless ($self->abandon_incomplete_events_for_stage($stage_name,$force_flag)) {
            return;
        }
        unless ($self->continue_with_abandoned_events_for_stage($stage_name,$force_flag)) {
            return;
        }
        unless ($self->ignore_unverified_events_for_stage($stage_name,$force_flag)) {
            return;
        }
        unless ($self->verify_successful_completion_for_stage($stage_name,$force_flag)) {
            return;
        }
        $self->remove_dependencies_on_stage($stage_name);
        # Should we set the build as Abandoned
    }
    return 1;
}

sub remove_dependencies_on_stage {
    my $self = shift;
    my $stage_name = shift;
    my $pp = $self->model->processing_profile;

    my @stages = $pp->stages;
    my $next_stage_name;
    for (my $i = 0; $i < scalar(@stages); $i++) {
        if ($stage_name eq $stages[$i]) {
            $next_stage_name = $stages[$i+1];
            last;
        }
    }
    if ($next_stage_name) {
        my $dependency = 'done("'. $self->model_id .'_'. $self->build_id .'_'. $stage_name .'*")';
        my @classes = $pp->classes_for_stage($next_stage_name);
        $self->_remove_dependency_for_classes($dependency,\@classes);
    }
}

sub _remove_dependency_for_classes {
    my $self = shift;
    my $dependency = shift;
    my $classes = shift;
    for my $class (@$classes) {
        if (ref($class) eq 'ARRAY') {
            $self->_remove_dependencey_for_classes($dependency,$class);
        } else {
            my @events = $class->get(
                                     event_status => 'Scheduled',
                                     model_id => $self->model_id,
                                     build_id => $self->build_id,
                                     user_name => ($ENV{'USER'} eq 'apipe' ? 'apipe-run' : $ENV{'USER'}),
                                 );
            for my $event (@events) {
                my $dependency_expression = $event->lsf_dependency_condition;
                unless ($dependency_expression) {
                    next;
                }
                my @current_dependencies = split(" && ",$dependency_expression);
                my @keep_dependencies;
                for my $current_dependency (@current_dependencies) {
                    if ($current_dependency eq $dependency) {
                        next;
                    }
                    push @keep_dependencies, $current_dependency;
                }
                my $new_expression = join(" && ",@keep_dependencies);
                if ($dependency_expression eq $new_expression) {
                    $self->error_message("Failed to modify dependency expression $dependency_expression by removing $dependency");
                    die;
                }
                $self->status_message("Changing dependency from '$dependency_expression' to '$new_expression' for event ". $event->id);
                my $lsf_job_id = $event->lsf_job_id;
                my $cmd = "bmod -w '$new_expression' $lsf_job_id";
                $self->status_message("Running:  $cmd");
                my $rv = system($cmd);
                unless ($rv == 0) {
                    $self->error_message('non-zero exit code returned from command: '. $cmd);
                    die;
                }
            }
        }
    }
}

#<>#

sub get_all_objects {
    my $self = shift;
    #TODO: child events no longer works
    my @events = $self->child_events;
    @events = sort {$b->id cmp $a->id} @events;
    my @objects = $self->SUPER::get_all_objects;
    return (@events, @objects);
}

sub abandon {
    my $self = shift;
    my $build = $self->build;
    my @events = sort { $a->genome_model_event_id <=> $b->genome_model_event_id }
        grep { $_->genome_model_event_id ne $self->genome_model_event_id } $build->events;
    for my $event (@events) {
        unless ($event->abandon) {
            $self->error_message('Failed to abandon event with id '. $event->id);
            return;
        }
    }
    my $disk_allocation = $build->disk_allocation;
    if ($disk_allocation) {
        my $reallocate = Genome::Disk::Allocation::Command::Reallocate->execute( allocator_id => $disk_allocation->allocator_id);
        unless ($reallocate) {
            $self->warning_message('Failed to reallocate disk space.');
        }
    }
    return $self->SUPER::abandon;
}


1;

