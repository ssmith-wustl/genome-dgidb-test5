package Genome::MiscUpdate; 

use strict;
use warnings;

class Genome::MiscUpdate {
    is => ['UR::Object'],
    table_name => 'gsc.misc_update misc_update',
    id_by => [
        subject_class_name      => { is => 'Text', len => 255, doc => 'the table in which the change occurred' },
        subject_id              => { is => 'Text', len => 255, doc => 'the primary key of the row that changed' },
        edit_date               => { is => 'Date', doc => 'the time of the change' },
    ],
    has => [
        editor_id               => { is => 'Text', len => 255, doc => 'the unix account that made the change' },
        subject_property_name   => { is => 'Text', len => 255, doc => 'the column whose value changed' },
        description             => { is => 'Text', len => 255, valid_values => ['INSERT', 'UPDATE', 'DELETE'], doc => 'the type of change (we do not currently track inserts)' },
        is_reconciled           => { is => 'Boolean', default => 0, doc => 'Indicates if the update has been applied to our tables'},
    ],
    has_optional => [
        old_value               => { is => 'Text', len => 1000, doc => 'the value which was changed' },
        new_value               => { is => 'Text', len => 1000, doc => 'the value to which old_value was changed' },
    ],
    data_source => 'Genome::DataSource::GMSchema',
    doc => 'The MISC_UPDATE table tracks changes to certain other tables in the gsc schema.'
};

sub to_string {
    my $self = shift;
    
    return sprintf(
        '[%s] %s: %s %s #%s, %s from %s to %s',
        $self->edit_date,
        $self->editor_id,
        $self->description,
        $self->subject_class_name,
        $self->subject_id,
        $self->subject_property_name,
        ($self->old_value || '<NULL>'),
        ($self->new_value || '<NULL>'),    
    );
}

1;
