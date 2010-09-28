package Genome::Model::Somatic::Command::ExampleManyModels; 

class Genome::Model::Somatic::Command::ExampleManyModels {
    is => 'Genome::Command::Base',
    has_many => [
        models => { shell_args_position => 1, is => 'Genome::Model' }, 
    ],
    doc => 'example command which works one or more models'
};

sub execute {
    my $self = shift;
    my @models = $self->models;
    print "models @models\n";
    return 1;
}

1;
