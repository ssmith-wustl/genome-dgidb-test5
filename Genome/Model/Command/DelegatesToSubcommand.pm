package Genome::Model::Command::DelegatesToSubcommand;

use strict;
use warnings;

use UR;
use Command; 

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Genome::Model::Command::LSFable',
#    is_abstract => 1,
    has => [ model => { is => 'String', doc => 'Identifies the genome model to use by name'},
             run_id => { is => 'Integer', doc => 'Identifies the run by id'},
           ], 
);




sub execute {
my $self = shift;
    $DB::single=1;

    # Which sub-command does the system think we should be doing here?
    unless ($self->can('sub_command_delegator')) {
        $self->error_message('command '.$self->command_name.' did not implement sub_command_delegator()');
    }
    my $sub_command_name = $self->sub_command_delegator;

    # Does the sub-command exist?
    # Make a mapping from sub-command names to fully qualified classes
    my %sub_command_types = map { my($type) = m/::(\w+)$/; $type => $_ } $self->sub_command_classes();

    my $sub_command_type = $sub_command_types{$sub_command_name};
    unless ($sub_command_type) {
        $self->error_message("sub command $sub_command_type is not known");
        return;
    }

    my $event = $self->create_or_get_event_by_jobid();
    return unless $event;
    $event->run_id($self->run_id);

    my $model = Genome::Model->get(name => $self->model);
    $event->genome_model_id($model->id);

    my $command = $sub_command_type->create(model => $self->model,
                                            run_id => $self->run_id);

    my $retval;
    if ($command) {
        $retval = $command->execute();
        $event->event_status($retval ? 'Succeeded' : 'Failed');
    } else {
        $event->event_status('Failed to create sub-command');
    }

    $event->date_completed(scalar(localtime));

    App::DB->sync_database();

    return $retval;
}

1;

