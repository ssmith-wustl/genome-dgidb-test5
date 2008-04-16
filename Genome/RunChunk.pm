package Genome::RunChunk;

use strict;
use warnings;

use File::Basename;

use Genome;
class Genome::RunChunk {
    type_name => 'run chunk',
    table_name => 'GENOME_MODEL_RUN',
    id_by => [
        genome_model_run_id => { is => 'NUMBER', len => 11 },
    ],
    has => [
        events              => { is => 'Genome::Model::Event', is_many => 1, reverse_id_by => "run" },
        full_path           => { is => 'VARCHAR2', len => 767 },
        limit_regions       => { is => 'VARCHAR2', len => 32, is_optional => 1 },
        run_name            => { is => 'VARCHAR2', len => 500, is_optional => 1 },
        sample_name         => { is => 'VARCHAR2', len => 255 },
        seq_id              => { is => 'NUMBER', len => 15, is_optional => 1 },
        sequencing_platform => { is => 'VARCHAR2', len => 255 },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};



sub name {
    my $self = shift;

    my $path = $self->full_path;

    my($name) = ($path =~ m/.*\/(.*EAS.*?)\/?$/);
    if (!$name) {
	$name = "run_" . $self->id;
    }
    return $name;
}

1;
