package Genome::Model::VariantValidation;

use strict;
use warnings;

use Genome;
class Genome::Model::VariantValidation {
    type_name => 'genome model variantvalidation',
    table_name => 'GENOME_MODEL_VARIANTVALIDATION',
    id_by => [
        model_id        => { is => 'NUMBER', len => 11 },
        validation_type => { is => 'VARCHAR2', len => 255 },
        variant_id      => { is => 'NUMBER', len => 10 },
    ],
    has => [
        model   => { is => 'Genome::Model', id_by => 'model_id', constraint_name => 'GMV_GM_FK' },
        variant => { is => 'Genome::Model::Variant', id_by => 'variant_id', constraint_name => 'GMV_GMV_FK' },
        validation_result    => { is => 'VARCHAR2', len => 10 },
        comments             => { is => 'VARCHAR2', len => 255, is_optional => 1 },
    ],
    schema_name => 'GMSchema',
    data_source => 'Genome::DataSource::GMSchema',
};

1;
