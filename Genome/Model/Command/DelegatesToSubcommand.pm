package Genome::Model::Command::DelegatesToSubcommand;

use strict;
use warnings;


use above "Genome";
use Command; 

UR::Object::Type->define(
    class_name => __PACKAGE__,
    is => 'Command',
    is_abstract => 1,
    doc => 'A helper abstract class with methods for delegating some methods to subclasses.  See also: Genome::Model::Command::DelegatesToSubcommand::WithRun and ::WithRefSeq',
    has => [
        model_id => { is => 'Integer', doc => 'Identifies the Genome::Model by id' },
        model => { is => 'Genome::Model', id_by => 'model_id', },
    ],
);


# Use the passed-in args to to determine the correct sub-sub command and create it
# Returns either the created command object, or "0 but true" to say that there was no
# sub-sub-command at that step.
sub create {
    my($class,%params) = @_;

    if ($class->can('_validate_params')) {
        unless ($class->_validate_params(%params)) {
            $class->error_message("Params did not validate, cannot create command $class");
            return;
        }
    }

    my $sub_command_class = $class->_get_sub_command_class_name(%params);
    unless ($sub_command_class) {
        return "0 but true";
    }

    my $self = $sub_command_class->create(%params,
                                          event_type => $sub_command_class->command_name,
                                          date_scheduled => UR::Time->now(),
                                          user_name => $ENV{'USER'});

    return $self;
}


sub _sub_command_name_to_class_name_map{
    my $class = shift;
    
    return map {
                    my ($type) = m/::(\w+)$/;
                    $type => $_
                }
                $class->sub_command_classes();
}

sub _get_sub_command_class_name{
    my $class = shift;
    
    my $sub_command_name = $class->_get_sub_command_name(@_);
    
    # Does the sub-command exist?
    my %sub_command_types = $class->_sub_command_name_to_class_name_map();

    my $sub_command_type = $sub_command_types{ucfirst($sub_command_name)};
    unless ($sub_command_type) {
        $class->error_message("sub command $sub_command_type is not known");
        return;
    }
    
    return $sub_command_type;
}

sub _get_sub_command_name{
    my $class = shift;
    
    # Which sub-command does the system think we should be doing here?
    unless ($class->can('sub_command_delegator')) {
        $class->error_message('command '.$class->command_name.' did not implement sub_command_delegator()');
        return;
    }
    
    return $class->sub_command_delegator(@_);
}

# Don't think this is used
#sub _get_or_create_then_init_event{
#    my $self = shift;
#    
#    my $event = $self->create_or_get_event_by_jobid();
#    return unless $event;
#    $event->run_id( $self->run_id );
#
#    $event->model_id($self->model_id);
#    
#    return $event;
#}


# When add-reads schedules these jobs, it uses the mid-level command 
# (assign-run) and not the most specific one (assign-run solexa).  Since
# the bsub_rusage is defined in the most specific class, the mid-level
# command should get the value from there
sub bsub_rusage {
    my $class = shift;

    #my $command =  $self->_create_sub_command();
    my $subcommand = $class->_get_sub_command_class_name();
    if ($subcommand->can('bsub_rusage')) {
        return $subcommand->bsub_rusage;
    } else {
        return '';
    }
}


1;

