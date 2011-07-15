package Genome::MiscNote;

use strict;
use warnings;

use Genome;
class Genome::MiscNote {
    type_name => 'misc note',
    table_name => 'MISC_NOTE',
    id_by => [
        id => { is => 'Number' },
    ],
    has => [
        subject_class_name => { is => 'Text' },
        subject_id         => { is => 'Text' },
        header_text        => { is => 'Text' },
        subject            => { is => 'UR::Object', id_class_by => 'subject_class_name', id_by => 'subject_id' },
        editor_id          => { is => 'Text' },
        entry_date         => { is => 'DateTime' },
    ],
    has_optional => [
        body_text          => { is => 'VARCHAR2' },
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

    unless ($self->body_text) {
        $self->body_text('');
    }

    my $sudo_username = Genome::Sys->sudo_username;
    if ($sudo_username) {
        $self->body_text($sudo_username . ' is running as ' . $self->editor_id . '. ' . $self->body_text);
    }

    return $self;
}

1;
