package Genome::MiscNote;

use strict;
use warnings;

use Genome;
class Genome::MiscNote {
    type_name => 'misc note',
    table_name => 'MISC_NOTE',
    id_by => [
        subject_class_name => { is => 'VARCHAR2', len => 255 },
        subject_id         => { is => 'VARCHAR2', len => 255 },
        header_text        => { is => 'VARCHAR2', len => 200 },
    ],
    has => [
        subject            => { is => 'UR::Object', id_class_by => 'subject_class_name', id_by => 'subject_id' },
        editor_id          => { is => 'VARCHAR2', len => 200 },
        entry_date         => { is => 'DATE' },
    ],
    has_optional => [
        body_text          => { is => 'VARCHAR2', len => 1000 },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    return unless $self;
        
    unless ($self->entry_date) {
        $self->entry_date(UR::Time->now);
    }

    unless ($self->editor_id) {
        $self->editor_id(Genome::Sys->username);
    }

    return $self;
}

1;
