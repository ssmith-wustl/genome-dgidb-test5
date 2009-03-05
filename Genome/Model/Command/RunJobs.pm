package Genome::Model::Command::RunJobs;

use strict;
use warnings;
use Genome;

class Genome::Model::Command::RunJobs {
    is => 'Genome::Model::Command',
    has => [
        dispatcher  => { is => 'String', is_optional => 1, default_value => 'lsf',
                        doc => 'underlying mechanism for executing jobs ("lsf" or "inline")', },
        instrument_data_id => {is => 'Integer', is_optional => 1, doc => 'only dispatch events with this instrument_data_id' },
        ref_seq_id  => {is => 'String', is_optional => 1, doc => 'only dispatch events with this ref_seq_id' },
        event_id    => {is => 'Integer', is_optional => 1, doc => 'only dispatch this single event' },
        bsub_queue  => {is => 'String', is_optional => 1, doc => 'lsf jobs should be put into this queue' },
        bsub_args   => {is => 'String', is_optional => 1, doc => 'additional arguments to be given to bsub' },
        prior_job_name => {is => 'String', is_optional => 1, doc => 'a job name to scheduled as a dependency for this job_name' },
        force           => {is => 'Boolean', is_optional => 1, doc => 'force kill an event and restart even if running/successful' },
        building    => {is => 'Boolean', default_value => '0', doc => 'a flag for building new models'},
    ],
};

sub sub_command_sort_position { 4 }

sub help_brief {
    'Launch all jobs for a model, and do all other job maintenance.'
}

sub help_synopsis {
    return <<'EOS'
run all jobs for a model on LSF:
  genome-model run-jobs tumor%v0b

run one job on LSF (possibly a crash/re-run):
  genome-model run-jobs tumor%v0b --event-id 1234 

run one job inline right here:
  genome-model run-jobs tumor%v0b --event-id 1234 --dispatch inline
EOS
}

sub help_detail {
    return <<EOS 
For the specified model, this tool does all job management, including:
- launch newly defined jobs for the model in LSF
- identify failed jobs and re-launch them
- identify jobs which should be pending in LSF but are not and resubmit them
- identify jobs which should be running in LSF but are not and resubmit them

This is run by the job monitor service for all active models (not currently deployed).
EOS
}

sub context {
    UR::Context->get_current();
}

sub event_types_without_subclass {
    return (
            '^genome[\- ]model build verify-successful-completion$',
            '^genome[\- ]model build assembly assemble newbler$',
            '^genome[\- ]model build amplicon-assembly',
            '^genome[\- ]model build combine-variants',     #
            '^genome[\- ]model build imported-annotation',  #TODO this question should be answered by the build
            '^genome[\- ]model build imported-variation',  #TODO  this question should be answered by the build
            '^genome[\- ]model build polyphred-polyscan',   #
            '^genome[\- ]model build reference-alignment deduplicate-libraries maq',
            '^genome[\- ]model build reference-alignment run-reports',
            
        );
}

sub execute {
    my $self = shift;

    #unless ($< == 10102) {
    #    $self->error_message("This module should only be run by via cron.");
    #    return;
    #}

    $DB::single = $DB::stopper;

    if ($self->event_id) {
        my $event = Genome::Model::Event->get($self->event_id);


        if ($event->event_status() ne 'Failed' and $event->event_status ne 'Crashed' and $event->event_status ne 'Scheduled'and $event->event_status ne 'Abandoned') {


            # this is a hack, but better than manually running these...
            # TODO: fix me
            unless ($self->force) {
                $event->error_message("Job is " . $event->event_status . ".  Use --force.");
                return;
            }
            if (my $lsf_job_id = $event->lsf_job_id) {
                my @bjobs = `bjobs $lsf_job_id`;
                if (@bjobs) {
                    $self->status_message($bjobs[-1]);
                    `bkill $lsf_job_id`;
                    sleep 5;
                    @bjobs = `bjobs $lsf_job_id`;
                    if (@bjobs) {
                        unless (grep {"DONE"} @bjobs) {
                        $self->error_message("Failed to kill job?\n" . $bjobs[-1]);
                        return;
                        }
                    } 
                }
            }
            $event->event_status("Crashed");
        }
        $event->revert;
        $self->context->commit;
    }

    if ($self->dispatcher eq 'inline') {
        if ($self->event_id) {
            return $self->_execute_inline_event($self->event_id);
        } else {
            $self->error_message('event_id param is required with dispatcher=inline');
            return;
        }
    }

    if ($self->dispatcher ne 'lsf') {
        $self->error_message("unknown dispatcher '".$self->dispatcher."'.  'lsf' and 'inline' are recognized");
        return;
    }

    #we could process a model name that is passed and have it set the model_id here.
    #if we wanted to allow model names to be passed in again

    my %addl_get_params = (model_id => $self->model_id) ; # model_id is a required param now
    if ($self->instrument_data_id) {
        $addl_get_params{'instrument_data_id'} = $self->instrument_data_id;
    }
    if (defined $self->ref_seq_id) {
        $addl_get_params{'ref_seq_id'} = $self->ref_seq_id;
    }
    if ($self->event_id) {
        $addl_get_params{'genome_model_event_id'} = $self->event_id;
    }
    unless ($self->building) {
        $self->_verify_submitted_jobs(%addl_get_params);
    }
    $self->_reschedule_failed_jobs(%addl_get_params);

    $self->_schedule_scheduled_jobs(%addl_get_params);

    return 1;
}


sub _execute_inline_event {
    my($self,$event_id) = @_;

    $DB::single = $DB::stopper;

    my $event = Genome::Model::Event->get($event_id);
    unless ($event->model_id == $self->model_id) {
        $self->error_message("The model id for the loaded event ".$event->model_id.
                             " does not match the command line ".$self->model_id);
        return;
    }

    my $result = $event->execute();
    if ($result) {
        $event->event_status("Succeeded");
    } else {
        # Shouldn't we do a rollback or something here?
        $event->event_status("Failed");
    }
    $event->date_completed(UR::Time->now);

    $self->context->commit;
}

# Find events in a 'Running' or 'Scheduled' state and have been submitted to lsf at some point
sub _verify_submitted_jobs {
    my($self,%addl_get_params) = @_;

    my @queued_events = 
        sort { 
            ($a->model_id <=> $b->model_id) 
            || 
            ($a->genome_model_event_id <=> $b->genome_model_event_id) 
        }
        Genome::Model::Event->get(
            event_status => ['Running','Scheduled'],
            lsf_job_id => { operator => 'ne', value => undef },
            build_id => { operator => 'ne', value => undef},
            %addl_get_params
        );
    my %invalid_dependencies;
    while (my $event = shift @queued_events) {
        unless ($event->ref_seq_id || $event->instrument_data_id) {
            unless (grep { $event->event_type =~ qr/$_/ }  $self->event_types_without_subclass) {
                $self->error_message('Event '. $event->id .' has no ref_seq_id or instrument id... skipping.');
                next;
            }
        }

        my $job_id = $event->lsf_job_id;
        my $job_state = $event->lsf_job_state;
        if (!$job_state || $job_state eq '' || $job_state eq 'EXIT' || $job_state eq 'DONE') {
            $self->status_message(
                $event->event_status
                . ' event ' 
                . event_desc($event) 
                . " has no LSF job $job_id.  Setting to crashed."
            );
            $event->event_status("Crashed");
        } elsif ($job_state eq 'PEND') {
            my @pending_reasons = $event->lsf_pending_reasons;
            if (scalar( grep { /Dependency condition invalid or never satisfied;/ } @pending_reasons )) {
                my $dependency_condition = $event->lsf_dependency_condition;
                $self->warning_message("The dependency condition '$dependency_condition' is invalid or never satisfied for lsf job '$job_id'");
                $invalid_dependencies{$event->model_id}{$event->build_id} = 1;
            }
        }
    } # end while @queued_events
    for my $model_id (keys %invalid_dependencies) {
        for my $build_id (keys %{$invalid_dependencies{$model_id}}) {
            my $update_state = Genome::Model::Command::Build::UpdateState->create(
                                                                                  model_id => $model_id,
                                                                                  build_id => $build_id,
                                                                                  force_flag => 0,
                                                                              );
            unless ($update_state) {
                $self->error_message("Failed to create command to update-state for model '$model_id' and  build '$build_id'");
                die;
            }
            unless ($update_state->execute) {
                $self->error_message('Failed to execute command: '. $update_state->command_name
                                     ." for model '$model_id' and build '$build_id'");
                die;
            }
        }
    }
    $self->context->commit;
    return 1;
}


sub event_desc {
    my ($event) = @_;
    my $s = $event->id . ': ' . $event->event_type . ' on ' . $event->model->name;
    if ($event->instrument_data_id) {
        $s .= ' for instrument data ' . $event->instrument_data->name;
    }
    elsif ($event->ref_seq_id) {
        $s .= ' for ref seq ' . $event->ref_seq_id
    }
    return $s;
}


# Find events in a 'Scheduled' state, but haven't been submitted to lsf
sub _schedule_scheduled_jobs {
    my($self,%addl_get_params) = @_;

    my @launchable_events = grep { $_->event_type !~ /create/ }
                            sort { ($a->model_id <=> $b->model_id) || ($a->genome_model_event_id <=> $b->genome_model_event_id) }
                            Genome::Model::Event->get( event_status => 'Scheduled',
                                                       lsf_job_id => undef,
                                                       build_id => { operator => 'ne', value => undef},
                                                       # this means the job hasn't been submitted yet
                                                       %addl_get_params);
    while (my $event = shift @launchable_events) {
        unless ($event->ref_seq_id || $event->instrument_data_id) {
            unless (grep { $event->event_type =~ qr/$_/ }  $self->event_types_without_subclass) {
                $self->error_message("Event ".$event->id." has no ref_seq_id or instrument_data_id... skipping.");
                next;
            }
        }
        my %execute_args = (bsub_queue => $self->bsub_queue, bsub_args => $self->bsub_args);

        my @done_dependencies;
        my $prior_event = $event->prior_event();
        if ($prior_event) {
            if ( $prior_event->lsf_job_id and 
                 ( $prior_event->event_status eq 'Running' or $prior_event->event_status eq 'Scheduled') ) {
                push @done_dependencies, $prior_event->lsf_job_id;
            }
        }
        if ($self->prior_job_name) {
            push @done_dependencies, '"'. $self->prior_job_name .'"';
        }
        if (@done_dependencies) {
            $execute_args{'dependency_hash_ref'}{done} = \@done_dependencies;
        }
        my $job_id = $event->execute_with_bsub(%execute_args);
        unless ($job_id) {
            $self->_failed_to_bsub($event, \@launchable_events);
            next;
        }

        $event->user_name($ENV{'USER'});
        $event->date_scheduled(UR::Time->now);
        $event->lsf_job_id($job_id);

        $self->context->commit;

    } # end while @launchable_events

    return 1;
}



sub _reschedule_failed_jobs {
    my($self,%addl_get_params) = @_;

    my @launchable_events = sort { ($a->model_id <=> $b->model_id) || ($a->id <=> $b->id) }
                            grep { $_->is_reschedulable }
                            grep { $_->lsf_job_id }    # Don't try to re-run a failed, non-lsf event
                                    # This grep wouldn't be necessary if we set old stuff to Abandoned
                            #grep { Genome::Model::Event->get(genome_model_event_id => { operator => '!=', value => $_->id },
                            #                                 event_status => ['Scheduled', 'Succeeded'], 
                            #                                 model_id => $_->model_id,
                            #                                 event_type => $_->event_type,
                            #                                 date_scheduled => { operator => '>', value => $_->date_scheduled } ) }
                                Genome::Model::Event->get(event_status => ['Failed','Crashed'],
                                                          build_id => { operator => 'ne', value => undef},
                                                          user_name => $ENV{'USER'},
                                                          %addl_get_params);

    while (my $event = shift @launchable_events) {
        # Get subsequent events that have been through a round of 'scheduling'.
        # ie. they have an lsf_job_id assigned to them.  These jobs will need to
        # be bmod-ded to have their dependancy condition changed
        my @subsequent_events = sort { ($a->model_id <=> $b->model_id) || ($a->id <=> $b->id) }
                                grep { $_->lsf_job_id }
                                Genome::Model::Event->get(
                                                          event_status => 'Scheduled',
                                                          prior_event_id => $event->genome_model_event_id,
                                                          user_name => $ENV{'USER'},
                                                      );
        my %execute_args = (bsub_queue => $self->bsub_queue, bsub_args => $self->bsub_args);

        my $prior_event = $event->prior_event();
        my @done_dependencies;
        if ($prior_event) {
            if ( $prior_event->lsf_job_id and 
                 ( $prior_event->event_status eq 'Running' or $prior_event->event_status eq 'Scheduled') ) {
                push @done_dependencies, $prior_event->lsf_job_id;
            }
        }

        if (@done_dependencies) {
            $execute_args{'dependency_hash_ref'}{done} = \@done_dependencies;
        }
        my $new_job_id = $event->execute_with_bsub(%execute_args);
        unless ($new_job_id) {
            $self->_failed_to_bsub($event, \@launchable_events);
            next;
        }

        $event->user_name($ENV{'USER'});
        $event->event_status('Scheduled');
        $event->date_scheduled(UR::Time->now);
        $event->date_completed(undef);
        $event->lsf_job_id($new_job_id);
        $event->retry_count($event->retry_count + 1);

        # Here since we originally scheduled in stages, we should not have to worry about job name/stage dependencies
        # The remaining events in the stage will get the new lsf_job_id dependency and that's all they should need
        foreach my $next_event ( @subsequent_events ) {
            my $new_dependency_string = "done($new_job_id)";
            my $next_job_id = $next_event->lsf_job_id;
            $self->status_message("Changing dependancy of lsf job $next_job_id to $new_job_id");
            $next_event->date_scheduled(UR::Time->now);   # Seems like the right thing to do
            `bmod -w '$new_dependency_string' $next_job_id`;
        }
        $self->context->commit;
    }
}


# If we had a problem scheduling a job, print an error message about it and
# remove any other events in the launchable_events list with the same model_id
sub _failed_to_bsub {
    my($self,$failed_event, $launchable_events) = @_;

    $self->error_message("Error running bsub for event " . $failed_event->id);

    my $model_id = $failed_event->model_id;
    my $i = 0;
    while ($i < @$launchable_events) {
        if ($launchable_events->[$i]->model_id == $model_id) {
            $self->warning_message("Skipping event " . $launchable_events->[$i]->id . " due to previous error.");
            # splice this one out of the list
            splice(@$launchable_events,$i, 1);
            next;
        }
        $i++;
    }
}


1;
