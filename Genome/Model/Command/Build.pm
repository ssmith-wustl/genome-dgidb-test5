package Genome::Model::Command::Build;

use strict;
use warnings;

use Genome;
class Genome::Model::Command::Build {
    is => ['Genome::Model::Event'],
    type_name => 'genome model build',
    table_name => 'GENOME_MODEL_BUILD',
    first_sub_classification_method_name => '_resolve_subclass_name',
    id_by => [
        build_id                 => { is => 'NUMBER', len => 10, constraint_name => 'GMB_GME_FK' },
    ],
    has => [
        model                    => { is => 'Genome::Model', id_by => 'model_id', constraint_name => 'GMB_GMM_FK' },
        data_directory           => { is => 'VARCHAR2', len => 1000, is_optional => 1 },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

sub resolve_data_directory {
    my $self = shift;
    my $model = $self->model;
    return $model->data_directory . '/build' . $self->id;
}

1;

