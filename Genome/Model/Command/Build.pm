package Genome::Model::Command::Build;

use strict;
use warnings;

use Genome;
use YAML;

class Genome::Model::Command::Build {
    is => [ 'Genome::Model::Event' ],
    type_name => 'genome model build',
    table_name => 'GENOME_MODEL_BUILD',
    id_by => [
        build_id => { is => 'NUMBER', len => 10, constraint_name => 'GMB_GME_FK' },
    ],
    has => [
        model          => { is => 'Genome::Model', id_by => 'model_id', constraint_name => 'GMB_GMM_FK' },
        data_directory => { is => 'VARCHAR2', len => 1000, is_optional => 1 },
        auto_execute   => { is => 'Boolean', default_value => 1, is_transient => 1, 
                         doc => 'The build will execute genome-model run-jobs before completing' },
        hold_run_jobs  => { is => 'Boolean', default_value => 0, is_transient => 1, 
                         doc => 'A flag to hold all lsf jobs that are scheduled in run-jobs' },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);

    my $model = $self->model;

    if ($model->current_running_build_id  && $model->current_running_build_id ne $self->build_id) {
        $self->error_message('Build('. $model->current_running_build_id .') is already running');
        die;
    }

    my @read_sets = $model->read_sets;

    # Temporary hack... PolyphredPolyscan and CombineVariants models do not have read sets...
    unless ($model->isa("Genome::Model::PolyphredPolyscan") or $model->isa("Genome::Model::CombineVariants")) {
        unless (scalar(@read_sets) && ref($read_sets[0])  &&  $read_sets[0]->isa('Genome::Model::ReadSet')) {
            $self->error_message('No read sets have been added to model: '. $model->name);
            $self->error_message("The following command will add all available read sets:\ngenome-model add-reads --model-id=".
            $model->id .' --all');
            return;
        }
    }
    $self->data_directory($self->resolve_data_directory);
    $model->current_running_build_id($self->build_id);

    return $self;
}

sub stages {
    my $class = shift;
    $class = ref($class) if ref($class);
    die("Please implement stages in class '$class'");
}

sub command_subclassing_model_property {
    return 'build_subclass_name';
}

sub resolve_data_directory {
    my $self = shift;
    my $model = $self->model;
    return $model->data_directory . '/build' . $self->id;
}

sub execute {
    my $self = shift;

    if ($self->child_events) {
        $self->error_message('Build '. $self->build_id .' already has child events. Will not build again.');
        return;
    }
    my $prior_job_name;
    for my $stage_name ($self->stages) {
        my @scheduled_objects = $self->_schedule_stage($stage_name);
        unless (@scheduled_objects) {
            $self->error_message('Problem with build('. $self->build_id .") objects not scheduled for classes:\n".
                                 join("\n",$self->classes_for_stage($stage_name)));
            die;
        }

        if (!defined $self->auto_execute) {
            # transent properties with default_values are not re-initialized when loading object from data source
            $self->auto_execute(1);
        }
        if ($self->auto_execute) {
            my %run_jobs_params = (
                                   model_id => $self->model_id,
                                   prior_job_name => $prior_job_name,
                                   building => 1,
                               );
            if ($self->hold_run_jobs) {
                $run_jobs_params{bsub_args} = ' -H ';
            }
            unless (Genome::Model::Command::RunJobs->execute(%run_jobs_params)) {
                $self->error_message('Failed to execute run-jobs for model '. $self->model_id);
                return;
            }
        }
        $prior_job_name = $self->model_id .'_'. $self->build_id .'_'. $stage_name .'*';
    }
    # this is really more of a 'testing' flag and may be more appropriate named such
    if ($self->auto_execute && !$self->hold_run_jobs) {
        $self->mail_summary;
    }
    return 1;
}

sub resolve_stage_name_for_class {
    my $self = shift;
    my $class = shift;
    for my $stage_name ($self->stages) {
        my $found_class = grep { $class =~ /^$_/ } $self->classes_for_stage($stage_name);
        if ($found_class) {
            return $stage_name;
        }
    }
    my $error_message = "No class found for '$class' in build ". $self->class ." stages:\n";
    for my $stage_name ($self->stages) {
        $error_message .= $stage_name ."\n";
        for my $class ($self->classes_for_stage($stage_name)) {
            $error_message .= "\t". $class ."\n";
        }
    }
    $self->error_message($error_message);
    return;
}

sub classes_for_stage {
    my $self = shift;
    my $stage_name = shift;
    my $classes_method_name = $stage_name .'_job_classes';
    return $self->$classes_method_name;
}

# TODO: write method for getting all objects for stage regardless of build status
sub objects_for_stage {
    my $self = shift;
    my $stage_name = shift;
    my $objects_method_name = $stage_name .'_objects';
    return $self->$objects_method_name;
}

sub events_for_stage {
    my $self = shift;
    my $stage_name = shift;
    my @events;
    for my $class ($self->classes_for_stage($stage_name)) {
        push @events, $self->events_for_class($class);
    }
    return @events;
}

sub events_for_class {
    my $self = shift;
    my $class = shift;

    my @class_events = $class->get(
                                   model_id => $self->model_id,
                                   parent_event_id => $self->build_id,
                               );
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
    my @can_not_verify_events = grep { !$_->can('verify_succesful_completion') } @succeeded_events;
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

sub verify_succesful_completion_for_stage {
    my $self = shift;
    my $stage_name = shift;
    my $force_flag = shift;

    my @stage_events = $self->events_for_stage($stage_name);
    my @succeeded_events = grep { $_->event_status eq 'Succeeded' } @stage_events;
    my @verifiable_events = grep { $_->can('verify_succesful_completion') } @succeeded_events;
    my @unverified_events = grep { !$_->verify_succesful_completion } @verifiable_events;
    if (@unverified_events) {
        my $status_message = 'Found '. scalar(@unverified_events) ." events that can not be verified succesful:\n";
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
                $self->error_messge('Illegal value '. $force_flag .' for continuing with unsuccesful events.');
            }
        }
    }
    return 1;
}

sub verify_succesful_completion {
    my $self = shift;
    for my $stage_name ($self->stages) {
        if ($stage_name eq 'verify_succesful_completion') {
            last;
        }
        unless ($self->verify_succesful_completion_for_stage($stage_name)) {
            $self->error_message('Failed to verify succesful completion of stage '. $stage_name);
            return;
        }
    }
    return 1;
}

sub update_build_state {
    my $self = shift;

    for my $stage_name ($self->stages) {
        if ($stage_name eq 'verify_succesful_completion') {
            last;
        }
        unless ($self->abandon_incomplete_events_for_stage($stage_name)) {
            return;
        }
        unless ($self->continue_with_abandoned_events_for_stage($stage_name)) {
            return;
        }
        unless ($self->ignore_unverified_events_for_stage($stage_name)) {
            return;
        }
        unless ($self->verify_succesful_completion_for_stage($stage_name)) {
            return;
        }
        $self->remove_dependencies_on_stage($stage_name);
        # Should we set the build as Abandoned
    }
    return 1;
}

sub X_force_stage {
    my $self = shift;
    my $stage_name = shift;

    my @stages = $self->stages;
    my $previous_stage_name;
    my $found_stage_name;
    for (my $i = 0; $i < scalar(@stages); $i++) {
        if ($stages[$i] eq $stage_name) {
            $found_stage_name = $stages[$i];
            $previous_stage_name = $stages[$i-1];
            last;
        }
    }
    unless ($found_stage_name) {
        $self->error_message("Failed to find stage '$stage_name'");
        $self->error_message("Available stages are:\n". join("\n",@stages));
        return;
    }
    if ($previous_stage_name) {
        my $dependency = 'done('. $self->model_id .'_'. $self->build_id .'_'. $previous_stage_name .'*)';
        my @classes = $self->classes_for_stage($previous_stage_name);
        $self->_remove_dependency_for_classes($dependency,\@classes);
    }
}

sub remove_dependencies_on_stage {
    my $self = shift;
    my $stage_name = shift;


    my @stages = $self->stages;
    my $next_stage_name;
    for (my $i = 0; $i < scalar(@stages); $i++) {
        if ($stage_name eq $stages[$i]) {
            $next_stage_name = $stages[$i+1];
            last;
        }
    }
    if ($next_stage_name) {
        my $dependency = 'done("'. $self->model_id .'_'. $self->build_id .'_'. $stage_name .'*")';
        my @classes = $self->classes_for_stage($next_stage_name);
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
                                     parent_event_id => $self->build_id,
                                     user_name => $ENV{'USER'},
                                 );
            for my $event (@events) {
                my $dependency_expression = $event->lsf_dependency_condition;
                unless ($dependency_expression) {
                    next;
                }
                my @current_dependencies = split(" && ",$dependency_expression);
                my @keep_dependencies;
                for my $current_dependency (@current_dependencies) {
                    if ($current_dependency cmp $dependency) {
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
                my $cmd = "bmod -w '$dependency_expression' $lsf_job_id";
                `$cmd`;
            }
        }
    }
}

sub _schedule_stage {
    my $self = shift;
    my $stage_name = shift;

    my @objects = $self->objects_for_stage($stage_name);
    unless (@objects) {
        $self->error_message('Problem with build('. $self->build_id .") no objects found for stage '$stage_name'\n");
        die;
    }
    my @scheduled_commands;
    foreach my $object (@objects) {
        my $object_class;
        my $object_id;
        if (ref($object)) {
            $object_class = ref($object);
            $object_id = $object->id;
        } elsif ($object == 1) {
            $object_class = 'single_instance';
        } else {
            $object_class = 'reference_sequence';
            $object_id = $object;
        }
        if ($object_class->isa('Genome::Model::ReadSet')) {
            my $run_chunk = $object->read_set;
            $self->status_message('Scheduling jobs for ' 
                . $run_chunk->sequencing_platform 
                . ' read set ' 
                . $run_chunk->full_name 
                . ' (' . $run_chunk->id . ')'
            );
        } elsif ($object_class eq 'reference_sequence') {
            $self->status_message('Scheduling jobs for reference sequence ' . $object_id);
        } elsif ($object_class eq 'single_instance') {
            $self->status_message('Scheduling '. $object_class .' for stage '. $stage_name);
        } else {
            $self->status_message('Scheduling for '. $object_class .' with id '. $object_id);
        }
        my @command_classes = $self->classes_for_stage($stage_name);
        push @scheduled_commands, $self->_schedule_command_classes_for_object($object,\@command_classes);
    }
    return @scheduled_commands;
}

sub _schedule_command_classes_for_object {
    my $self = shift;
    my $object = shift;
    my $command_classes = shift;
    my $prior_event_id = shift;

    my @scheduled_commands;
    for my $command_class (@{$command_classes}) {
        if (ref($command_class) eq 'ARRAY') {
            push @scheduled_commands, $self->_schedule_command_classes_for_object($object,$command_class,$prior_event_id);
        } else {
            if ($command_class->can('command_subclassing_model_property')) {
                my $subclassing_model_property = $command_class->command_subclassing_model_property;
                unless ($self->model->$subclassing_model_property) {
                    # TODO: move into the creation of the processing profile
                    #$self->status_message("This processing profile doesNo value defined for $subclassing_model_property in the processing profile.  Skipping related processing...");
                    next;
                }
            }
            my $command;
            if ($command_class->isa('Genome::Model::EventWithRefSeq')) {
                if (ref($object)) {
                    unless ($object->isa('Genome::Model::RefSeq')) {
                        my $error_message = 'Expecting Genome::Model::RefSeq for EventWithRefSeq but got '. ref($object);
                        $self->error_message($error_message);
                        die;
                    }
                    $command = $command_class->create(
                                                      model_id => $self->model_id,
                                                      ref_seq_id => $object->ref_seq_id,
                                                  );
                } else {
                    $command = $command_class->create(
                                                      model_id => $self->model_id,
                                                      ref_seq_id => $object,
                                                  );
                }
            } elsif ($command_class->isa('Genome::Model::EventWithReadSet')) {
                unless ($object->isa('Genome::Model::ReadSet')) {
                    my $error_message = 'Expecting Genome::Model::ReadSet object but got '. ref($object);
                    $self->error_message($error_message);
                    die;
                }
                $command = $command_class->create(
                                                  read_set_id => $object->read_set_id,
                                                  model_id => $self->model_id,
                                              );
                $object->first_build_id($self->build_id);
            } elsif ($command_class->isa('Genome::Model::Event')) {
                $command = $command_class->create(
                                                  model_id => $self->model_id,
                                              );
            }
            unless ($command) {
                my $error_message = 'Problem creating subcommand for class '
                    . ' for object class '. ref($object)
                        . ' model id '. $self->model_id
                            . ': '. $command_class->error_message();
                $self->error_message($error_message);
                die;
            }
            $command->parent_event_id($self->id);
            $command->prior_event_id($prior_event_id);
            $command->schedule;
            $prior_event_id = $command->id;
            push @scheduled_commands, $command;
            my $object_id;
            if (ref($object)) {
                $object_id = $object->id;
            } else {
                $object_id = $object;
            }
            $self->status_message('Scheduled '. $command_class .' for  '. $object_id
                                  .' event_id '. $command->genome_model_event_id ."\n");
        }
    }
    return @scheduled_commands;
}

sub mail_summary {
    my $self = shift;

    my $model = $self->model;
    
    my $sendmail = "/usr/sbin/sendmail -t";
    my $from = "From: ssmith\@genome.wustl.edu\n";
    my $reply_to = "Reply-to: thisisafakeemail\n";
    my $subject = "Subject: Build Summary.\n";
    my $content = 'This is the Build Summary for your model '. $model->name .' and build '. $self->id ."\n";
    my $to = "To: " . $self->user_name . '@genome.wustl.edu' . "\n";

    $content .= 'https://gscweb.gsc.wustl.edu/cgi-bin/'. $model->sequencing_platform
        .'/genome-model-stage1.cgi?model-name='. $model->name  ."&refresh=1\n\n";
    if ($model->sequencing_platform eq 'solexa') {
        $content .= 'https://gscweb.gsc.wustl.edu/cgi-bin/'. $model->sequencing_platform
            .'/genome-model-stage2.cgi?model-name=' . $model->name  ."&refresh=1\n";
    }

    open(SENDMAIL, "|$sendmail") or die "Cannot open $sendmail: $!";
    print SENDMAIL $reply_to;
    print SENDMAIL $from;
    print SENDMAIL $subject;
    print SENDMAIL $to;
    print SENDMAIL $content;
    close(SENDMAIL);
    return 1;
}

sub _ask_user_question {
    my $self = shift;
    my $question = shift;

    my $input;
  ASK: while (!$SIG{ALRM}) {
        $self->status_message($question);
        $self->status_message("Please reply: 'yes' or 'no'");
        alarm(60);
        chomp($input = <STDIN>);
        last ASK if ($input =~ m/yes|no/);
    }
    alarm(0);
    return $input;
}

sub get_all_objects {
    my $self = shift;

    my @events = $self->child_events;
    if ($events[0] && $events[0]->id =~ /^\-/) {
        @events = sort {$b->id cmp $a->id} @events;
    } else {
        @events = sort {$a->id cmp $b->id} @events;
    }
    my @objects = $self->SUPER::get_all_objects;
    return (@events, @objects);
}

sub yaml_string {
    my $self = shift;
    my $string = YAML::Dump($self);
    my @objects = $self->get_all_objects;
    for my $object (@objects) {
        $string .= $object->yaml_string;
    }
    return $string;
}

sub delete {
    my $self = shift;

    my $model = $self->model;
    if ($model->current_running_build_id && $model->current_running_build_id eq $self->genome_model_event_id) {
        $model->current_running_build_id(undef);
    }

    if ($model->last_complete_build_id && $model->last_complete_build_id eq $self->genome_model_event_id) {
        $model->last_complete_build_id(undef);
    }
    my @objects = $self->get_all_objects;
    for my $object (@objects) {
        unless ($object->delete) {
            $self->error_message('Failed to remove object '. $object->class .' '. $object->id);
            return;
        }
    }
    return $self->SUPER::delete;
}

1;

