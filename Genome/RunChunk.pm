package Genome::RunChunk;

use strict;
use warnings;

use File::Basename;

use Genome;
UR::Object::Type->define(
    class_name => 'Genome::RunChunk',
    english_name => 'run chunk',
    table_name => 'RUN',
    id_by => [
        id => { is => 'INT', len => 11 },
    ],
    has => [
        events              => {is => 'Genome::Model::Event', is_many => 1, reverse_id_by => 'model'},
        models              => { via => 'events', to => 'model'},
        full_path           => { is => 'VARCHAR', len => 767 },
        limit_regions       => { is => 'VARCHAR', len => 32, is_optional => 1 },
        sequencing_platform => { is => 'VARCHAR', len => 255 },
    ],
    unique_constraints => [
        { properties => [qw/id/], sql => 'PRIMARY' },
        { properties => [qw/full_path limit_regions sequencing_platform/], sql => 'SQLITE_AUTOINDEX_RUN_1' },
        { properties => [qw/full_path limit_regions sequencing_platform/], sql => 'FAKE_MCPK' },
    ],
    schema_name => 'Main',
    data_source => 'Genome::DataSource::Main',
);


sub name {
    my $self = shift;

    my $path = $self->full_path;

    my($name) = ($path =~ m/.*\/(.*EAS.*?)\//);
    if (!$name) {
	$name = "run_" . $self->id;
    }
    return $name;
}

1;
