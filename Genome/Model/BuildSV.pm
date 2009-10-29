package Genome::Model::BuildSV;

use strict;
use warnings;

use Genome;
class Genome::Model::BuildSV {
    type_name => 'genome model build sv',
    table_name => 'GENOME_MODEL_BUILD_SV',
    id_by => [
        build_id   => { is => 'NUMBER', len => 10, implied_by => 'genome_model_build' },
        variant_id => { is => 'NUMBER', len => 10 },
    ],
    has => [
        allele_frequency   => { is => 'NUMBER', len => 12 },
        breakdancer_score  => { is => 'NUMBER', len => 12 },
        genome_model_build => { is => 'Genome::Model::Build', id_by => 'build_id', constraint_name => 'GMBSV_GMB_FK' },
        num_reads          => { is => 'NUMBER', len => 12 },
        num_reads_lib      => { is => 'NUMBER', len => 12 },
        run_param          => { is => 'NUMBER', len => 12 },
        somatic_status     => { is => 'VARCHAR2', len => 20 },
        version            => { is => 'NUMBER', len => 12 },
        genome_model_sv    => { is => 'Genome::Model::SV', id_by => 'variant_id', constraint_name => 'GMBSV_GMSV_FK' },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

1;
