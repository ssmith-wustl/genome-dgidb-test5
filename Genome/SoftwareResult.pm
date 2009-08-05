package Genome::SoftwareResult;

use strict;
use warnings;

use Genome;

class Genome::SoftwareResult {
    type_name => 'software result',
    table_name => 'SOFTWARE_RESULT',
    id_by => [
        id => { is => 'NUMBER', len => 20 },
    ],
    has => [
        software => { is => 'Genome::Software', is_transient => 1},
        software_class_name => { via => 'software', to => 'class' },
        software_version    => { is => 'VARCHAR2', len => 64, column_name => 'VERSION', is_optional => 1 },
        result_class_name   => { is => 'VARCHAR2', len => 255, column_name => 'CLASS_NAME' },
        inputs_bx   => { is => 'UR::BoolExpr', id_by => 'inputs_id', is_optional => 1 },
        inputs_id   => { is => 'VARCHAR2', len => 4000, column_name => 'INPUTS_ID', implied_by => 'inputs_bx', is_optional => 1 },
        params_bx   => { is => 'UR::BoolExpr', id_by => 'params_id', is_optional => 1 },
        params_id   => { is => 'VARCHAR2', len => 4000, column_name => 'PARAMS_ID', implied_by => 'params_bx', is_optional => 1 },
        output  => { is => 'VARCHAR2', len => 1000, column_name => 'OUTPUTS_PATH', is_optional => 1 },
    ],
    
    sub_classification_method_name => 'result_class_name',
    is_abstract => 1,
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

sub get_by_inputs_id {
    my $class = shift;
    my $inputs_id = shift;

    my $self = $class->SUPER::get(inputs_id => $inputs_id);
    if ($self) {
        #TODO: get software by version or diff versions
        my $software = $self->software_class_name->create(inputs_id => $self->inputs_id);
        my %inputs = $self->inputs;
        for my $key (keys %inputs) {
            #Set input property values for software
            $software->$key($inputs{$key});
        }
    }
    return $self;
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    return unless $self;

    my $software = $self->software;
    $self->inputs_bx($software->inputs_bx) unless defined $self->inputs_bx;
    $self->software_version($software->resolve_software_version) unless defined $self->software_version;
    $self->result_class_name($class);
    return $self;
}

sub inputs {
    my $self = shift;
    my $bx;
    if (@_) {
        $bx = UR::BoolExpr->resolve_normalized_rule_for_class_and_params($self->class_name,@_);
        $self->inputs_id($bx->id);
    }
    else {
        $bx = $self->inputs_bx;
    }
    return $bx->params_list;
}

sub params {
    my $self = shift;
    my $bx;
    if (@_) {
        $bx = UR::BoolExpr->resolve_normalized_rule_for_class_and_params($self->class_name,@_); 
        $self->_params_id($bx->id);
    }
    else {
        $bx = $self->_params_bx;
    }
    return $bx->params_list;
}

sub _get_input_by_name {
    my $self = shift;
    my $input_name = shift;

    my %inputs = $self->inputs;

    return $inputs{$input_name}
};

1;

#$Rev$:
#$HeadURL$:
#$Id$:
    
