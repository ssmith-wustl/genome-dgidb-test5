package Genome::Model::Command::Build::Start;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';
use Regexp::Common;

class Genome::Model::Command::Build::Start {
    is => 'Command',
    doc => "Create and start a build.",
    has => [
        model_identifier => {
            is => 'Text',
            doc => 'Model identifier.  Use model id or name.',
        },
        lsf_queue => {
            default_value => 'apipe',
            is_constant => 1,
        },
    ],
    has_optional => [
        force => {
            is => 'Boolean',
            default_value => 0,
            doc => 'Force a new build even if existing builds are running.',
        },
        model => {
            is => 'Genome::Model',
            doc => 'Model to build.'
        },
        build => {
            is => 'Genome::Model::Build',
            doc => 'Da build.'
        },
    ],
};

#< Command >#
sub sub_command_sort_position { 1 }

sub help_brief {
    return 'Start a new build';
}

#< Execute >#
sub execute {
    my $self = shift;

    # Get model
    my $model = $self->_resolve_model
        or return;

    # Check running builds, only if we are not forcing
    unless ( $self->force ) {
        $self->_verify_no_other_builds_running
            or return;
    }

    # Create the build
    my $build = Genome::Model::Build->create(
        model_id => $model->id,
    );
    unless ( $build ) {
        $self->error_message( 
            sprintf("Can't create build for model (%s %s)", $model->id, $model->name) 
        );
        return;
    }
    $self->build($build);
    Genome::Utility::FileSystem->create_directory( $build->data_directory )
        or return;

    # Schedule the stages and convert them to workflows
    my $stages = $build->schedule
        or return;
    my @workflow_stages;
    foreach my $stage ( @$stages ) {
        my $workflow_stage = $self->_workflow_for_stage( $stage )
            or next; # this is ok
        push @workflow_stages, $workflow_stage;
    }

    return 1 unless @workflow_stages; # ok, may not have stages
    
    # FIXME check for errors here???
    my $w = $self->_merge_stage_workflows(@workflow_stages);
    $w->save_to_xml(OutputFile => $build->data_directory . '/build.xml');

    my $resource = "-R 'select[type==LINUX86]'";
    my $add_args = '';

    if (scalar @$stages == 1 && scalar @{ $stages->[0]->{events} } == 1) {
        my $one_event = $stages->[0]->{events}->[0];
        
        $resource = $one_event->bsub_rusage;
        $add_args = ' --inline';
    }

    # Bsub
    my $build_event = $build->build_event;
    my $lsf_command = sprintf(
        'bsub -N -H -q %s -m blades %s -g /build/%s -u %s@genome.wustl.edu -o %s -e %s genome model services build run%s --model-id %s --build-id %s',
        $self->lsf_queue,
        $resource,
        $ENV{USER},
        $ENV{USER}, 
        $build_event->output_log_file,
        $build_event->error_log_file,
        $add_args,
        $model->id,
        $build->id,
    );

    my $job_id = $self->_execute_bsub_command($lsf_command)
        or return;
    $build_event->lsf_job_id($job_id);
    UR::Context->create_subscription(
        method => 'commit',
        callback => sub{
            `bresume $job_id`;
        },
    );

    printf(
        "Build (ID: %s DIR: %s) created, scheduled and launched to LSF.\nAn initialization email will be sent once the build begins running.\n",
        $build->id,
        $build->data_directory,
    );

    return 1;
}

sub _resolve_model {
    my $self = shift;

    # Make sure we got an identifier
    my $model_identifier = $self->model_identifier;
    unless ( $model_identifier ) {
        $self->error_message("No model identifier given to get model.");
        return;
    }

    my $model;
    # By id if it's an integer
    if ( $self->model_identifier =~ /^$RE{num}{int}$/ ) {
        $model = Genome::Model->get($model_identifier);
    }

    # Try by name if id wasn't an integer or didn't work
    unless ( $model ) {
        $model = Genome::Model->get(name => $model_identifier);
    }

    # Neither worked
    unless ( $model ) {
        $self->error_message("Can't get model for identifier ($model_identifier).  Tried getting as id and name.");
        return;
    }

    return $self->model($model);
}

sub _verify_no_other_builds_running {
    my $self = shift;

    my @running_builds = $self->model->running_builds;
    if ( @running_builds ) {
        $self->error_message(
            sprintf(
                "Model (%s %s) already has builds running: %s. Use the 'force' param to overirde this and start a new build.",
                $self->model->id,
                $self->model->name,
                join(', ', map { $_->id } @running_builds),
            )
        );
        return;
    } 

    return 1;
}
#<>#

#< LSF >#
sub _execute_bsub_command { # here to overload in testing
    my ($self, $cmd) = @_;

    my $bsub_output = `$cmd`;
    my $rv = $? >> 8;
    if ( $rv ) {
        $self->error_message("Failed to launch bsub (exit code: $rv) command:\n$bsub_output");
        return;
    }

    if ( $bsub_output =~ m/Job <(\d+)>/ ) {
        return "$1";
    } 
    else {
        $self->error_message("Launched busb command, but unable to parse bsub output: $bsub_output");
        return;
    }
}
#<>#

#< Workflow >#
sub _merge_stage_workflows {
    my $self = shift;
    my @workflows = @_;
    
    my $w = Workflow::Model->create(
        name => $self->build->id . ' all stages',
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
    my ($self, $stage_from_build) = @_;

    my $stage_name = $stage_from_build->{name};
    my @events = @{$stage_from_build->{events}};
    unless (@events){
        $self->error_message('Failed to get events for stage '. $stage_name);
        return;
    }
    my $lsf_queue = $self->lsf_queue;

    my $stage = Workflow::Model->create(
        name => $self->build->id . ' ' . $stage_name,
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
    my ($self, $event) = @_;

    $event->create_log_directory; # dies upon failure
    
    return ' -o '.$event->output_log_file.' -e '.$event->error_log_file;
}
#<>#

1;

#$HeadURL$
#$Id$
