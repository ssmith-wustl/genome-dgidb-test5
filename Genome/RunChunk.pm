package Genome::RunChunk;

use strict;
use warnings;

use File::Basename;

use Genome;
UR::Object::Class->define(
    class_name => 'Genome::RunChunk',
    english_name => 'run chunk',
    table_name => 'run',
    id_by => [
        id => { is => 'integer' },
    ],
    has => [
        full_path           => { is => 'varchar2(1000)' },
        limit_regions       => { is => 'varchar2(32)', is_optional => 1 },
        sequencing_platform => { is => 'varchar2(255)' },
        events              => {is => 'Genome::Model::Event', is_many => 1, reverse_id_by => 'model'},
        models              => { via => 'events', to => 'model'},
    ],
    schema_name => 'Main',
    data_source => 'Genome::DataSource::Main',
);


sub name {
    my $self = shift;

    my $path = $self->full_path;

    my($name) = ($path =~ m/.*\/(\S*?)\/[Dd]ata/);
    if (!$name) {
	$name = "run_" . $self->id;
    }
    return $name;
}

1;
