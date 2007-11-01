package Genome::Model::Command::DelegatesToSubcommand::WithRefSeq;

use strict;
use warnings;

use above "Genome";
use Command; 

UR::Object::Class->define(
    class_name => __PACKAGE__,
    is => 'Genome::Model::Command::DelegatesToSubcommand',
    is_abstract => 1,
    has => [ 
             ref_seq_id => { is => 'Integer', doc => 'Identifies the refseq'},
           ], 
);


sub _create_sub_command {
    my $self = shift;
    my $sub_command_type = $self->_get_sub_command_class_name();

    my $command = $sub_command_type->create(model_id => $self->model_id,
                                            ref_seq_id => $self->ref_seq_id,
					    event_type => $sub_command_type->command_name,
					    date_scheduled => App::Time->now(),
					    user_name => $ENV{'USER'},
					   );


}

1;

