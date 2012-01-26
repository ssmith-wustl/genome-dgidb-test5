package Genome::SoftwareResult::Input;

use strict;
use warnings;

use Genome;
class Genome::SoftwareResult::Input {
    type_name => 'software result input',
    table_name => 'SOFTWARE_RESULT_INPUT',
    id_by => [
        input_name         => { is => 'VARCHAR2', len => 100 },
        software_result_id => { is => 'NUMBER', len => 20 },
    ],
    has => [
        input_value                     => { is => 'VARCHAR2', len => 1000 },
        software_result                 => { is => 'Genome::SoftwareResult', id_by => 'software_result_id', constraint_name => 'SRI_SR_FK' },
        
        # new, not dependent until old snapshots are gone and data is complete
        name                            => { is => 'Text', len => 255 },
        value_class_name                => { is => 'Text', len => 255 },
        value_id                        => { is => 'Text', len => 1000 },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

# this will sync up new columns with the old ones
# once all old snapshots are gone, we will switch to the new columns and remove this
sub create {
    my $self = shift->SUPER::create(@_);
    return unless $self;

    $self->name($self->input_name);
    $self->value_id($self->input_value);

    my $sr = $self->software_result;
    if ($sr) {
        my $p = $sr->__meta__->property($self->input_name);
        if ($p) {
            $self->value_class_name($p->_data_type_as_class_name);
        }
        else {
            $self->value_class_name('UR::Value::Text');
        }
    }

    return $self;
};

1;

