package Genome::Model::Command::DelegatesToSubcommand;

use strict;
use warnings;

use UR;
use Command; 

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Genome::Model::Command::LSFable',
    is_abstract => 1,
    has => [ model_id => { is => 'Integer', doc => 'Identifies the genome model to use by ID'},
             run_id => { is => 'Integer', doc => 'Identifies the run by id'},
           ], 
);

sub execute {
my $self = shift;
    $DB::single=1;

    my $sub_command_type = $self->_get_sub_command_class_name();
 
    my $model = Genome::Model->get(id => $self->model_id);

    my $command = $sub_command_type->create(model_id => $self->model_id,
                                            run_id => $self->run_id,
					    event_type => $sub_command_type->command_name,
					    date_scheduled => App::Time->now(),
					    user_name => $ENV{'USER'}
					   );

    my $retval;
    if ($command) {
        $retval = $command->execute();
        $command->event_status($retval ? 'Succeeded' : 'Failed');
    } else {
        $command->event_status('Failed to create sub-command');
    }

    $command->date_completed(scalar(localtime));

    App::DB->sync_database();

    return $retval;
}

sub _sub_command_name_to_class_name_map{
    my $self = shift;
    
    return map {
                    my ($type) = m/::(\w+)$/;
                    $type => $_
                }
                $self->sub_command_classes();
}

sub _get_sub_command_class_name{
    my $self = shift;
    
    my $sub_command_name = $self->_get_sub_command_name();
    
    # Does the sub-command exist?
    my %sub_command_types = $self->_sub_command_name_to_class_name_map();

    my $sub_command_type = $sub_command_types{ucfirst($sub_command_name)};
    unless ($sub_command_type) {
        $self->error_message("sub command $sub_command_type is not known");
        return;
    }
    
    return $sub_command_type;
}

sub _get_sub_command_name{
    my $self = shift;
    
    # Which sub-command does the system think we should be doing here?
    unless ($self->can('sub_command_delegator')) {
        $self->error_message('command '.$self->command_name.' did not implement sub_command_delegator()');
    }
    
    return $self->sub_command_delegator;
}

sub _get_or_create_then_init_event{
    my $self = shift;
    
    my $event = $self->create_or_get_event_by_jobid();
    return unless $event;
    $event->run_id( $self->run_id );

    $event->model_id($self->model_id);
    
    return $event;
}

1;

