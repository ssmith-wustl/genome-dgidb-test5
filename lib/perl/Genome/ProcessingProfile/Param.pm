package Genome::ProcessingProfile::Param;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::Param {
    type_name => 'processing profile param',
    table_name => 'PROCESSING_PROFILE_PARAM',
    id_by => [
        processing_profile => {
            is => 'Genome::ProcessingProfile',
            id_by => 'processing_profile_id',
            constraint_name=> 'PPP_PP_FK',
        },
        name            => { is => 'VARCHAR2', len => 100, column_name => 'PARAM_NAME' },
        value           => { is => 'VARCHAR2', len => 1000, column_name => 'PARAM_VALUE' },
    ],
    has => [
        # new, not dependent until old snapshots are gone and data is complete
        _name                           => { is => 'Text', len => 255, column_name => 'NAME' },
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

    $self->_name($self->name);
    $self->value_id($self->value);

    my $sr = $self->processing_profile;
    if ($sr) {
        my $p = $sr->__meta__->property($self->name);
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
