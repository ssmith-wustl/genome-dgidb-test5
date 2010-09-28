package Genome::Model::Somatic::Command::ExampleOneModel; 

class Genome::Model::Somatic::Command::ExampleOneModel {
    is => 'Genome::Command::Base',
    has => [
        model => { shell_args_position => 1, is => 'Genome::Model' }, 
    ],
    doc => 'example command which works on one model'
};

sub execute {
    my $self = shift;
    my $model = $self->model;
    print "model $model\n";
    return 1;
}

1;
