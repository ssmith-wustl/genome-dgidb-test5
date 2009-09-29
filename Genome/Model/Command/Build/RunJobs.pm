package Genome::Model::Command::Build::RunJobs;

use strict;
use warnings;

use Genome;
use Workflow;

use Regexp::Common;

class Genome::Model::Command::Build::RunJobs {
    is => 'Genome::Model::Command',
    has => [
            build_id =>{
                         is => 'Number',
                         doc => 'The id of the build in which to update status',
                         is_optional => 1,
                     },
            build   => {
                        is => 'Genome::Model::Build',
                        id_by => 'build_id',
                        is_optional => 1,
                    },
            stage_name => { is => 'Text', },
            auto_execute   => {
                          is => 'Boolean',
                          default_value => 1,
                          is_transient => 1,
                          is_optional => 1,
                          doc => 'run-jobs will execute the workflow(default_value=1)',
                      },
            bsub_queue  => {is => 'String', is_optional => 1, doc => 'lsf jobs should be put into this queue' },
    ],
    doc => 'launch all jobs for a build (old)',
};

sub sub_command_sort_position { 3 }

sub help_detail {
    return <<EOS 
EOS
}
sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    unless (defined $self->build_id ) {
        my $model = $self->model;
        unless ($model) {
            $self->delete;
            return;
        }
        my $build_id = $model->current_running_build_id;
        unless ($build_id) {
            $self->error_message('Failed to get build_id for model '. $model->id);
        }
        $self->build_id($build_id);
    }
    unless ( $self->_verify_build ) {
        $self->delete;
        return;
    }
    return $self;
}

sub _verify_build {
    my $self = shift;

    unless ( defined $self->build_id ) {
        $self->error_message("No build id given");
        return;
    }

    unless ( $self->build_id =~ /^$RE{num}{int}$/ ) {
        $self->error_message( sprintf('Build id given (%s) is not an integer', $self->build_id) );
        return;
    }

    unless ( $self->build ) {
        $self->error_message( sprintf('Can\'t get build for id (%s) ', $self->build_id) );
        return;
    }

    return 1;
}

sub execute {
    my $self = shift;

    my $build = $self->build;
    my $build_event = $build->build_event;

    $DB::single=1;
    
    my $lsf_queue = $self->bsub_queue || 'apipe';

    my $stage = Workflow::Model->create(
                                        name => $self->build_id . ' ' . $self->stage_name,
                                        input_properties => [
                                                             'prior_result',
                                                         ],
                                        output_properties => ['result']
                                    );
    my $input_connector = $stage->get_input_connector;
    my $output_connector = $stage->get_output_connector;

    my @events = $build_event->events_for_stage($self->stage_name);
    unless (@events){
        $self->error_message('Failed to get events for stage '. $self->stage_name);
        return;
    }
    my @ops_to_merge = ();
    my @first_events = grep { !defined($_->prior_event_id) } @events;
    for my $first_event ( @first_events ) {
        my $first_operation = $stage->add_operation(
                                                    name => $first_event->command_name_brief .' '. $first_event->id,
                                                    operation_type => Workflow::OperationType::Event->get(
                                                                                                          $first_event->id
                                                                                                      )
                                                );
        my $first_event_log_resource = $self->resolve_log_resource($first_event);

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
                    my $n_event_log_resource = $self->resolve_log_resource($n_event);
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
#    $stage->as_png($self->build->data_directory .'/'. $self->stage_name .'.png');
    $stage->save_to_xml(OutputFile => $self->build->data_directory . '/' . $self->stage_name . '.xml');
#    print $stage->save_to_xml;

    if ($self->auto_execute) {
        require Workflow::Simple;

#        $Workflow::Simple::store_db = 0;
        my $output = Workflow::Simple::run_workflow_lsf(
                                           $stage,
                                           prior_result => 1
                                       );
                                       
        unless ($output) {
            $self->error_message("Stage '" . $self->stage_name . "' failed.");
            foreach my $error (@Workflow::Simple::ERROR) {
                $self->error_message($error->path_name . ':' . $error->error);
            }
            die;
        }

    }
    return 1;
}

sub resolve_log_resource {
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

1;
