package Genome::Model::Input;

use strict;
use warnings;

use Genome;

class Genome::Model::Input {
    type_name => 'genome model input',
    table_name => 'GENOME_MODEL_INPUT',
    id_by => [
    value_class_name => { is => 'VARCHAR2', len => 255, },
    value_id         => { is => 'VARCHAR2', len => 1000, },
    model_id         => { is => 'NUMBER', len => 11, },
    name             => { is => 'VARCHAR2', len => 255, },
    ],
    has => [
    model => { 
        is => 'Genome::Model',
        id_by => 'model_id',
        constraint_name => 'GMI_GM_FK',
    },
    model_name => {
        via => 'model',
        to => 'name',
    },
    value => {
        is => 'UR::Object',
        id_by => 'value_id',
        id_class_by => 'value_class_name',
    },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

sub __create {
    my ($class, %params) = @_;

    #FIXME Can't get to work in UR...auto set the class name when using primitive 
    
    unless ( $params{value} ) {
        unless ( defined $params{value_id} ) {
            $class->error_message("No value or value id given.");
            return;
        }

        unless ( $params{value_class_name} ) {
            $params{value_class_name} = 'UR::Value';
        }
    }
    
    return $class->SUPER::create(%params);
}

1;

#$HeadURL$
#$Id$
