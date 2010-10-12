package Genome::Model::Command::Define::Benchmark;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Define::Benchmark {
    is => 'Genome::Model::Command::Define',
    has => [
        command_arguments => {
            doc => 'arguments for the command used in the processing profile',
            is_optional => 1,
            value => ' '
        }
    ]
};

sub execute {
    my $self = shift;

    my $result = $self->SUPER::_execute_body(@_);
    return unless $result;

    my $model = Genome::Model->get($self->result_model_id);
    unless ($model) {
        $self->error_message("No model generated for " . $self->result_model_id);
        return;
    }

    my $args = $self->command_arguments || undef;
    my $i = $model->add_input(value_class_name => 'UR::Value', value_id => $args, name => 'command_arguments');
    unless ($i) {
        $self->error_message("Failed to add command_arguments input");
        $model->delete;
        return;
    }

    return $result;
}

1;

