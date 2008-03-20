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
             run => { is => 'Genome::RunChunk', id_by => 'run_id' },
           ], 
);


sub _validate_params {
    my($class,%params) = @_;

    unless ($params{'model_id'} && $params{'run_id'}) {
        $class->error_message("both model_id and run_id are required params when creating a $class");
        return;
    }

    unless (Genome::Model->get(id => $params{'model_id'})) {
        $class->error_message("There is no model with id ".$params{'model_id'});
        return;
    }

    unless (Genome::RunChunk->get(id => $params{'run_id'}) ) {
        $class->error_message("There is no run with id ".$params{'run_id'});
        return;
    }

    return 1;
}


1;

