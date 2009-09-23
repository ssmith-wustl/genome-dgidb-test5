package Genome::Model::Command::Build;

use strict;
use warnings;

use Genome;
use Data::Dumper;

class Genome::Model::Command::Build {
    is => [ 'Genome::Model::Event' ],
    doc => "Build the model with currently assigned instrument data according to the processing profile.",
    has => [
        data_directory => { via => 'build' },
        auto_execute   => {
            is => 'Boolean',
            default_value => 1,
            is_transient => 1,
            is_optional => 1,
            doc => 'The build will execute genome model build run-jobs(default_value=1)',
        },
        force_new_build => {
            is => 'Boolean',
            default_value => 0,
            doc => 'Force a new build when existing builds are running',
            is_optional => 1,
        },
        bsub_queue  => {
            is => 'String', 
            is_optional => 1, 
            default_value => 'apipe',
            doc => 'lsf jobs should be put into this queue',
        },
    ],
};

sub sub_command_sort_position { 3 }

# Why is this here? "Build" is both a noun and a verb.
# "genome model build list" ends up getting routed here as Genome::Model::Command::Build takes precedence.
# redirect that into the right place.
# -ben

sub resolve_class_and_params_for_argv {
    my $class = shift;
    my @args = @_;

    if ($class eq "Genome::Model::Command::Build" && grep {$_ eq "list"} @args) {
        my ($list, @list_args) = @args;
        return Genome::Model::Build::Command::List->resolve_class_and_params_for_argv(@list_args);
    } else {
        return $class->SUPER::resolve_class_and_params_for_argv(@args);
    }
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    unless ($self) {
        $class->error_message("Failed to create build command: " . $class->error_message());
        return;
    }
    unless (defined $self->auto_execute) {
        $self->auto_execute(1);
    }
    my $model = $self->model;
    unless ($self->build_id) {
        my @running_builds = $model->running_builds;
        my $ids = join "\n", map {$_->id} @running_builds;
        if (@running_builds > 0) {
            $self->warning_message("This model already has one (or more) builds currently running.\n IDs are: $ids\n");
            if (!$self->force_new_build) {
                $self->error_message("Use the --force-new-build param to force a new build to run.  ");
                return;
            }
        } 
        my $build = Genome::Model::Build->create(
            model_id => $model->id,
        );
        unless ($build) {
            $self->error_message('Failed to create new build for model '. $model->id);
            $self->delete;
            return;
        }
        $self->build_id($build->build_id);
    }
    my @build_events = Genome::Model::Command::Build->get(
        model_id => $model->id,
        build_id => $self->build_id,
        genome_model_event_id => { operator => 'ne', value => $self->id},
    );
    if (scalar(@build_events)) {
        my $error_message = 'Found '. scalar(@build_events) .' build event(s) that already exist for build id '.
        $self->build_id;
        for (@build_events) {
            $error_message .= "\n". $_->desc ."\t". $_->event_status ."\n";
        }
        $self->error_message($error_message);
        $self->delete;
        return;
    }

    my $build = $self->build;
    unless ($build) {
        $self->error_message('No build found for build id '. $self->build_id);
        $self->delete;
        return;
    }

    $self->schedule; # in G:M:Event, sets status, times, etc.

    return $self;
}

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

sub Xresolve_data_directory {
    my $self = shift;
    my $model = $self->model;
    return $model->data_directory . '/build' . $self->id;
}

sub execute {
    my $self = shift; 
    my $build = $self->build;
    unless ($build) {
        $self->error_message('No build found for build id '. $self->build_id);
        return;
    }
    my @events = grep { $_->id != $self->id } $build->events;
    if (scalar(@events)) {
        my $error_message = 'Build '. $build->build_id .' already has events.' ."\n";
        for (@events) {
            $error_message .= "\t". $_->desc .' '. $_->event_status ."\n";
        }
        $error_message .= 'For build event: '. $self->desc .' '. $self->event_status;
        return;
    }

    $self->bsub_queue('apipe') unless $self->bsub_queue;

    $self->create_directory($self->data_directory);

    my $pp = $self->model->processing_profile;
    for my $stage_name ($pp->stages) {
        my @scheduled_objects = $self->_schedule_stage($stage_name);
        unless (@scheduled_objects) {
            $self->error_message('WARNING: Stage '. $stage_name .' for build ('. $self->build_id .") failed to schedule objects for classes:\n".
                                 join("\n",$pp->classes_for_stage($stage_name)));
            next;
        }

    }

    my @stage_wf = ();
    #= map { $self->_workflow_for_stage($_) } $pp->stages;

    foreach my $stage ($pp->stages) {
        my $w = $self->_workflow_for_stage($stage);
        if ($w) {
            push @stage_wf, $w;
        }
    }

    if (@stage_wf) {
        my $w = $self->_merge_stage_workflows(@stage_wf);

        $w->save_to_xml(OutputFile => $self->build->data_directory . '/build.xml');

        if ($self->auto_execute) {
            my $cmdline = 'bsub -N -H -q ' . $self->bsub_queue . ' -m blades -u ' . $ENV{USER} . '@genome.wustl.edu' .
                $self->_resolve_log_resource($self) . ' ' . 
                'genome model build run --model-id ' . $self->model->id . ' --build-id ' . $self->build->id;

            my $bsub_output = `$cmdline`;
            my $retval = $? >> 8;

            if ($retval) {
                $self->error_message("bsub returned a non-zero exit code ($retval), bailing out");
                return;
            }
            my $bsub_job_id;
            if ($bsub_output =~ m/Job <(\d+)>/) {
                $bsub_job_id = $1;
            } else {
                $self->error_message('Unable to parse bsub output, bailing out');
                $self->error_message("The output was: $bsub_output");
                return;
            }
            $self->lsf_job_id($bsub_job_id);
            #$self->build->start;# FIXME return here on failure?
            my $resume = sub { `bresume $bsub_job_id`};
            UR::Context->create_subscription(method => 'commit', callback => $resume);
        }
    }

    return 1;
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

sub _merge_stage_workflows {
    my $self = shift;
    my @workflows = @_;
    
    my $w = Workflow::Model->create(
        name => $self->build_id . ' all stages',
        input_properties => [
            'prior_result'
        ],
        output_properties => [
            'result'
        ]
    );
    
    my $last_op = $w->get_input_connector;
    my $last_op_prop = 'prior_result';
    foreach my $inner (@workflows) {    
        $inner->workflow_model($w);

        $w->add_link(
            left_operation => $last_op,
            left_property => $last_op_prop,
            right_operation => $inner,
            right_property => 'prior_result'
        );
        
        $last_op = $inner;
        $last_op_prop = 'result';
    }
    
    $w->add_link(
        left_operation => $last_op,
        left_property => $last_op_prop,
        right_operation => $w->get_output_connector,
        right_property => 'result'
    );
    
    return $w;
}

sub _workflow_for_stage {
    my ($self, $stage_name) = @_;
    my $build = $self->build;
    
    my $build_event = $build->build_event;

    $DB::single=1;
    
    my $lsf_queue = 'apipe'; #$self->bsub_queue || 'apipe';

    my @events = $build_event->events_for_stage($stage_name);
    unless (@events){
        $self->error_message('Failed to get events for stage '. $stage_name);
        return;
    }


    my $stage = Workflow::Model->create(
                                        name => $self->build_id . ' ' . $stage_name,
                                        input_properties => [
                                                             'prior_result',
                                                         ],
                                        output_properties => ['result']
                                    );
    my $input_connector = $stage->get_input_connector;
    my $output_connector = $stage->get_output_connector;

    my @ops_to_merge = ();
    my @first_events = grep { !defined($_->prior_event_id) } @events;
    for my $first_event ( @first_events ) {
        my $first_operation = $stage->add_operation(
                                                    name => $first_event->command_name_brief .' '. $first_event->id,
                                                    operation_type => Workflow::OperationType::Event->get(
                                                                                                          $first_event->id
                                                                                                      )
                                                );
        my $first_event_log_resource = $self->_resolve_log_resource($first_event);

        $first_operation->operation_type->lsf_resource($first_event->bsub_rusage . $first_event_log_resource);
        $first_operation->operation_type->lsf_queue($lsf_queue);

        $stage->add_link(
                         left_operation => $input_connector,
                         left_property => 'prior_result',
                         right_operation => $first_operation,
                         right_property => 'prior_result'
                     );
        my $output_connector_linked = 0;
        my $sub;
        $sub = sub {
            my $prior_op = shift;
            my $prior_event = shift;
            my @events = $prior_event->next_events;
            if (@events) {
                foreach my $n_event (@events) {
                    my $n_operation = $stage->add_operation(
                                                            name => $n_event->command_name_brief .' '. $n_event->id,
                                                            operation_type => Workflow::OperationType::Event->get(
                                                                                                                  $n_event->id
                                                                                                              )
                                                        );
                    my $n_event_log_resource = $self->_resolve_log_resource($n_event);
                    $n_operation->operation_type->lsf_resource($n_event->bsub_rusage . $n_event_log_resource);
                    $n_operation->operation_type->lsf_queue($lsf_queue);

                    $stage->add_link(
                                     left_operation => $prior_op,
                                     left_property => 'result',
                                     right_operation => $n_operation,
                                     right_property => 'prior_result'
                                 );
                    $sub->($n_operation,$n_event);
                }
            } else {
                ## link the op's result to it.
                unless ($output_connector_linked) {
                    push @ops_to_merge, $prior_op;
                    $output_connector_linked = 1;
                }
            }
        };
        $sub->($first_operation,$first_event);
    }

    my $i = 1;
    my @input_names = map { 'result_' . $i++ } @ops_to_merge;
    my $converge = $stage->add_operation(
                                         name => 'merge results',
                                         operation_type => Workflow::OperationType::Converge->create(
                                                                                                     input_properties => \@input_names,
                                                                                                     output_properties => ['all_results','result']
                                                                                                 )
                                     );
    $i = 1;
    foreach my $op (@ops_to_merge) {
        $stage->add_link(
                         left_operation => $op,
                         left_property => 'result',
                         right_operation => $converge,
                         right_property => 'result_' . $i++
                     );
    }
    $stage->add_link(
                     left_operation => $converge,
                     left_property => 'result',
                     right_operation => $output_connector,
                     right_property => 'result'
                 );

    return $stage;
}


sub _resolve_log_resource {
    my $self = shift;
    my $event = shift;

    my $event_id = $event->genome_model_event_id;
    my $log_dir = $event->resolve_log_directory;
    unless (-d $log_dir) {
        $event->create_directory($log_dir);
    }
    my $err_log_file = sprintf("%s/%s.err", $log_dir, $event_id);
    my $out_log_file = sprintf("%s/%s.out", $log_dir, $event_id);
    return ' -o ' . $out_log_file . ' -e ' . $err_log_file;
}

sub _schedule_stage {
    my $self = shift;
    my $stage_name = shift;
    my $pp = $self->model->processing_profile;
    my @objects = $pp->objects_for_stage($stage_name,$self->model);
       my @scheduled_commands;
    foreach my $object (@objects) {
        my $object_class;
        my $object_id; 
        if (ref($object)) {
            $object_class = ref($object);
            $object_id = $object->id;
        } elsif ($object eq '1') {
            $object_class = 'single_instance';
        } else {
            $object_class = 'reference_sequence';
            $object_id = $object;
        }
        if ($object_class->isa('Genome::InstrumentData')) {
            $self->status_message('Scheduling jobs for '
                . $object_class . ' '
                . $object->full_name
                . ' (' . $object->id . ')'
            );
        } elsif ($object_class eq 'reference_sequence') {
            $self->status_message('Scheduling jobs for reference sequence ' . $object_id);
        } elsif ($object_class eq 'single_instance') {
            $self->status_message('Scheduling '. $object_class .' for stage '. $stage_name);
        } else {
            $self->status_message('Scheduling for '. $object_class .' with id '. $object_id);
        }
        my @command_classes = $pp->classes_for_stage($stage_name);
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
            if ($command_class =~ /MergeAlignments|UpdateGenotype|FindVariations/) {
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
            } elsif ($command_class =~ /AlignReads|TrimReadSet|AssignReadSetToModel|AddReadSetToProject|FilterReadSet/) {
                if ($object->isa('Genome::InstrumentData')) {
                    my $ida = Genome::Model::InstrumentDataAssignment->get(
                                                                           model_id => $self->model_id,
                                                                           instrument_data_id => $object->id,
                                                                       );
                    unless ($ida) {
                        #This seems like duplicate logic but works best for the mock models in test case
                        my $model = $self->model;
                        ($ida) = grep { $_->instrument_data_id == $object->id} $model->instrument_data_assignments;
                        unless ($ida) {
                            $self->error_message('Failed to find InstrumentDataAssignment for instrument data '. $object->id .' and model '. $self->model_id);
                            die $self->error_message;
                        }
                    }
                    unless ($ida->first_build_id) {
                        $ida->first_build_id($self->build_id);
                    }
                    $command = $command_class->create(
                                                      instrument_data_id => $object->id,
                                                      model_id => $self->model_id,
                                                  );
                } else {
                    my $error_message = 'Expecting Genome::InstrumentData object but got '. ref($object);
                    $self->error_message($error_message);
                    die;
                }
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
            $command->build_id($self->build_id);
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
            $self->status_message('Scheduled '. $command_class .' for '. $object_id
                                  .' event_id '. $command->genome_model_event_id ."\n");
        }
    }
    return @scheduled_commands;
}

#< Email Initialization and Completion Reports >#
sub report_class_for_build_success {
    # Overwrite in your build if you'd like - a summary perhaps?
    return 'Genome::Model::Report::BuildSuccess';
}

## Does anything actually invoke this?
sub email_build_start_report {
    my $self = shift;

    my $generator = Genome::Model::Report::BuildStart->create(build_id => $self->build_id);
    unless ( $generator ) { 
        $self->error_message("Can't create build start report generator");
        return;
    }

    my $report = $generator->generate_report; # SAVE report??
    unless ( $report ) { 
        $self->error_message("Can't generate report for build start");
        return;
    }
    
    my $confirmation = Genome::Report::Email->send_report(
        report => $report,
        to => $self->user_name.'@genome.wustl.edu',
        from => 'apipe@genome.wustl.edu',
        replyto => 'noreply@genome.wustl.edu',
        # maybe not the best/correct place for this information but....
        xsl_file_for_html => Genome::Model::Report::BuildStart->get_xsl_file_for_html,
        image_files => [  Genome::Model::Report::BuildStart->get_footer_image_info ],  
    );
    unless ( $confirmation ) {
        $self->error_message("Couldn't email build start report");
        return;
    }

    return 1;
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


package Genome::Model::Command::Build::AbstractBaseTest;

class Genome::Model::Command::Build::AbstractBaseTest {
    is => 'Genome::Model::Command::Build',
};

package Genome::Model::Command::Build::AbstractBaseTest::StageOneJobOne;

class Genome::Model::Command::Build::AbstractBaseTest::StageOneJobOne {
    is => 'Genome::Model::Event',
};

sub verify_successful_completion {
    return 1;
}

package Genome::Model::Command::Build::AbstractBaseTest::StageOneJobTwo;

class Genome::Model::Command::Build::AbstractBaseTest::StageOneJobTwo {
    is => 'Genome::Model::Event',
};

sub verify_successful_completion {
    return 0;
}

package Genome::Model::Command::Build::AbstractBaseTest::StageOneJobThree;

class Genome::Model::Command::Build::AbstractBaseTest::StageOneJobThree {
    is => 'Genome::Model::Event',
};

package Genome::Model::Command::Build::AbstractBaseTest::StageTwoJobOne;

class Genome::Model::Command::Build::AbstractBaseTest::StageTwoJobOne {
    is => 'Genome::Model::Event',
};

package Genome::Model::Command::Build::AbstractBaseTest::StageTwoJobTwo;

class Genome::Model::Command::Build::AbstractBaseTest::StageTwoJobTwo {
    is => 'Genome::Model::Event',
};

1;

