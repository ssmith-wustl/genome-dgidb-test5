package Genome::Model::Command::Define::Benchmark;

use strict;
use warnings;

use Genome;

class Genome::Model::Command::Define::Benchmark {
    is => 'Genome::Model::Command::Define',
    has_optional => [
        subject_id => {
            is => 'Number',
            len => 15,
            is_input => 1,
            doc => '(unused for benchmark)',
            value => '2875295544'  
        },
        subject_class_name => {
            is => 'Text',
            len => 500,
            is_input => 1,
            doc => '(unused for benchmark)', 
            value => 'Genome::Individual'
        },
        subject_name => {
            is => 'Text',
            len => 255,
            is_input => 1,
            doc => '(unused for benchmark)',
        },
        command_arguments => {
            doc => 'arguments for the command used in the processing profile',
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

sub listed_params {
    return qw/ id name data_directory processing_profile_id processing_profile_name /;
}


1;

