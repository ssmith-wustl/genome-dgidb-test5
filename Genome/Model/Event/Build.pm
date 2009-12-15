package Genome::Model::Event::Build;

use strict;
use warnings;

use Genome;

# this stub exists only so command_name still returns the type_name expected by the database 

class Genome::Model::Event::Build {
    is => [ 'Genome::Model::Event' ],
    has => [
        data_directory => { via => 'build' },
    ],
};

sub command_name {
    my $class = ref($_[0]) || $_[0];
    return $class->SUPER::command_name unless $class eq __PACKAGE__;
    return 'genome model build';
}

sub command_name_brief {
    my $class = ref($_[0]) || $_[0];
    return $class->SUPER::command_name_brief unless $class eq __PACKAGE__;
    return 'build';
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
