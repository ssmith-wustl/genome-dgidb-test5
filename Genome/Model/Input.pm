package Genome::Model::Input;

use strict;
use warnings;

use Genome;

class Genome::Model::Input {
    type_name => 'genome model input',
    table_name => 'GENOME_MODEL_INPUT',
    id_by => [
        value_class_name => { is => 'VARCHAR2', len => 255 },
        value_id         => { is => 'VARCHAR2', len => 1000, implied_by => 'value' },
        model_id         => { is => 'NUMBER', len => 11, implied_by => 'model' },
        name             => { is => 'VARCHAR2', len => 255 },
    ],
    has => [
        model        => { is => 'Genome::Model', id_by => 'model_id', constraint_name => 'GMI_GM_FK' },
        model_name   => { via => 'model', to => 'name' },
        
        # i think this...
        value        => { is => 'UR::Object', id_by => 'value_id', id_class_by => 'value_class_name' },
        
        # was supposed to be this...?

        # value_object => { is => 'UR::Object', id_by => 'value_id', id_class_by => 'value_class_name' },
        # value        => { 
        #     calculate => q|$value_class_name->isa("UR::Value") ? $value_object : $value_id| 
        #     calculate_from => [qw/value_class_name value_id value_object/], 
        # }, 
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

sub __display_name__ {
    my $self = shift;

    return $self->value_class_name . ': ' . $self->value_id;
}

1;

#$HeadURL$
#$Id$
