package Genome::Model::Command::DelegatesToSubcommand;

use strict;
use warnings;


use above "Genome";
use Command; 

UR::Object::Type->define(
    class_name => __PACKAGE__,
    is => 'Command',
    is_abstract => 1,
    has => [ model_id => { is => 'Integer', doc => 'Identifies the genome model to use by ID'},
           ], 
);


sub create {
    my $class = shift;

$DB::single=1;
    my $self = $class->SUPER::create(@_);
    my $correct_subcommand = $self->_get_or_create_sub_command(@_);
    $correct_subcommand->event_status('Scheduled');

    return $correct_subcommand;
}


sub execute {
1;
}
#sub execute {
#my $self = shift;
#    $DB::single=1;
#
#    my $command =  $self->_create_sub_command();
#
#    my $retval;
#    if ($command) {
#        $retval = $command->execute();
#        
##        $command->date_completed(UR::Time->now());
##        $command->event_status($retval ? 'Succeeded' : 'Failed');
#        
#        return $retval;
#        
#    } else {
#        $command->event_status('Failed to create sub-command');
#        return;
#    }
#}

sub _create_sub_command {
    my $self = shift;
    my $sub_command_type = $self->_get_sub_command_class_name();

    my $command = $sub_command_type->create(model_id => $self->model_id,
					    event_type => $sub_command_type->command_name,
					    date_scheduled => UR::Time->now(),
					    user_name => $ENV{'USER'},
					   );

}


sub _get_or_create_sub_command {
    my $self = shift;
    my %args = @_;

    my $sub_command_type = $self->_get_sub_command_class_name();

    delete $args{' '};
    my @commands = $sub_command_type->get(%args,
                                          event_status => 'Scheduled');
    if (! @commands) {
        return $sub_command_type->create( %args,
                                          event_type => $sub_command_type->command_name,
                                          date_scheduled => UR::Time->now(),
                                          user_name => $ENV{'USER'},
                                         );

    } elsif (@commands == 1) {
        return $commands[0];

    } else {
        @commands = sort { $a->date_scheduled cmp $b->date_scheduled } @commands;
        return $commands[0];
    }
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
        return;
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


# When add-reads schedules these jobs, it uses the mid-level command 
# (assign-run) and not the most specific one (assign-run solexa).  Since
# the bsub_rusage is defined in the most specific class, the mid-level
# command should get the value from there
sub bsub_rusage {
    my $self = shift;

    #my $command =  $self->_create_sub_command();
    my $command = $self->_get_sub_command_class_name();
    if ($command->can('bsub_rusage')) {
        return $command->bsub_rusage;
    } else {
        return '';
    }
}


1;

