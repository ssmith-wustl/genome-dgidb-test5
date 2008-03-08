package Genome::Model::Command::DelegatesToSubcommand::WithRun;

use strict;
use warnings;

use above "Genome";
use Command; 

UR::Object::Type->define(
    class_name => __PACKAGE__,
    is => 'Genome::Model::Command::DelegatesToSubcommand',
    is_abstract => 1,
    has => [ 
             run_id => { is => 'Integer', doc => 'Identifies the run by id'},
           ], 
);


sub _create_sub_command {
    my $self = shift;
    my $sub_command_type = $self->_get_sub_command_class_name();

#$DB::single=1;
    my $command = $sub_command_type->create(model_id => $self->model_id,
                                            run_id => $self->run_id,
                                            event_type => $sub_command_type->command_name,
                                            date_scheduled => UR::Time->now(),
                                            user_name => $ENV{'USER'},
                                          );
    return $command;



    # The add-reads top-level step may have (probably) made an event record
    # as a byproduct of some of its other work
    my %args = (model_id => $self->model_id,
                run_id => $self->run_id,
                event_type => $sub_command_type->command_name,
                user_name => $ENV{'USER'},
               );
    my @possible_commands = $sub_command_type->get(%args,
                                                   event_status => { operator => '!=', value => 'Failed'},
                                                  );
    unless (@possible_commands) {
        my $command = $sub_command_type->create(%args,
                                                date_scheduled => UR::Time->now(),
                                               );
        return $command;
    }

    my @commands = sort { $a->id <=> $b->id }
                   @possible_commands;

    return $commands[0];
}

1;

