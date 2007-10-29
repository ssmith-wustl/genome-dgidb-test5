
package Genome::Model::Command::Analyze;

use strict;
use warnings;

use above "Genome";
use Command; 

class Genome::Model::Command::Analyze {
    is => 'Command',
    has => [
        model          => { is => 'Genome::Model', id_by => 'model_id', constraint_name => 'event_genome_model' },
        model_id       => { is => 'INT', len => 11, implied_by => 'model_id' },
    ]
};

sub sub_command_sort_position { 9 }

sub help_brief {
    "analyze data about a given genome"
}


# Example for sub-classes:
# 
#sub execute {
#    my $self = shift;
#    print $self->model_id . " is the model id\n";
#    print $self->model . " is the model\n";
#}

1;

