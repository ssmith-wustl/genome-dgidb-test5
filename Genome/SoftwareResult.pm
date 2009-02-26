package Genome::SoftwareResult;

use strict;
use warnings;

use Genome;

class Genome::SoftwareResult {
    table_name => 'SOFTWARE_RESULT',
    id_by => [
        id           => { is => 'NUMBER', len => 10 },
    ],
    has => [
        class_name   => { is => 'VARCHAR2', len => 255 },
        version      => { is => 'VARCHAR2', len => 64, is_optional => 1 },

        
        _inputs_bx    => { is => 'UR::BoolExpr', id_by => '_inputs_id' }, # object from blob
        _inputs_id    => { is => 'VARCHAR2', len => 4000, is_optional => 1, column_name => 'INPUTS_ID' }, # blob

        _params_bx    => { is => 'UR::BoolExpr', id_by => '_params_id' }, # object from blob
        _params_id    => { is => 'VARCHAR2', len => 4000, is_optional => 1, column_name => 'ARAMS_ID' }, # blob

        outputs_path => { is => 'VARCHAR2', len => 1000, is_optional => 1 },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

sub inputs {
    my $self = shift;
    my $bx;
    if (@_) {
        $bx = UR::BoolExpr->resolve_for_class_and_params($self->class_name,@_);
        $self->_inputs_id($bx->id);
    }
    else {
        $bx = $self->_inputs_bx;
        
    }
    return $bx->params_list;
}

sub params {
    my $self = shift;
    my $bx;
    if (@_) {
        $bx = UR::BoolExpr->resolve_for_class_and_params($self->class_name,@_);
        $self->_params_id($bx->id);
    }
    else {
        $bx = $self->_params_bx;
    }
    return $bx->params_list;
}

1;
