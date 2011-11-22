use strict;
use warnings;
use Genome;

class Genome::Model::ClinSeq {
    is => 'Genome::Model',
    has_optional_input => [
        wgs_model       => { is => 'Genome::Model::SomaticVariation' },
        exome_model     => { is => 'Genome::Model::SomaticVariation' },
        rnaseq_model    => { is => 'Genome::Model::RnaSeq' },
    ],
    has_optional_param => [
        someparam1 => { is => 'Number', doc => 'blah' },
        someparam2 => { is => 'Boolean', doc => 'blah' },
        someparam2 => { is => 'Text', valid_values => ['a','b','c'], doc => 'blah' },
    ],
    doc => 'clinial sequencing data convergence of RNASeq, WGS and exome capture data',
};

1;

__END__


        tumor_model => {
            is => 'Genome::Model::ReferenceAlignment',
            id_by => 'tumor_model_id',
        },
        tumor_build_id => {
            is => 'Text',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'tumor_build', value_class_name => 'Genome::Model::Build::ReferenceAlignment'],
            is_many => 0,
            is_mutable => 1,
            is_optional => 1,
            doc => 'last complete tumor build, updated when a new SomaticVariation build is created',
        },
