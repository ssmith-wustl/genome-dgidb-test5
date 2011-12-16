package Genome::Model::Build::ImportedVariationList;


use strict;
use warnings;

use Data::Dumper;
use Genome;

class Genome::Model::Build::ImportedVariationList {
    is => 'Genome::Model::Build',
    has => [
        version => { 
            via => 'inputs',
            is => 'Text',
            to => 'value_id', 
            where => [ name => 'version', value_class_name => 'UR::Value'], 
            is_mutable => 1 
        },
        reference => {
            is => 'Genome::Model::Build::ImportedReferenceSequence',
            via => 'model',
            to => 'reference',
        },
    ],
    has_optional_mutable => {
        snv_result => {
            is => 'Genome::Model::Tools::DetectVariants2::Result::Base',
            doc => 'The result for snvs to import',
            via => 'inputs',
            to => 'value',
            where => [
                name => 'snv_result',
            ],
        },
        indel_result => {
            is => 'Genome::Model::Tools::DetectVariants2::Result::Base',
            doc => 'The result for indels to import',
            via => 'inputs',
            to => 'value',
            where => [
                name => 'indel_result',
            ],
        },
        sv_result => {
            is => 'Genome::Model::Tools::DetectVariants2::Result::Base',
            doc => 'The result for svs to import',
            via => 'inputs',
            to => 'value',
            where => [
                name => 'sv_result',
            ],
        },
        cnv_result => {
            is => 'Genome::Model::Tools::DetectVariants2::Result::Base',
            doc => 'The result for cnvs to import',
            via => 'inputs',
            to => 'value',
            where => [
                name => 'cnv_result',
            ],
        },
    },
};

sub snvs_bed {
    my ($self, $version) = @_;
    # TODO: get a real api for this
    my $name = $self->model->name . "-" . $self->version;
    if (defined $version and $version ne "v1") {
        die "No version of snvs .bed file version $version available for $name";
    }

    return join('/', $self->snv_result->output_dir, 'snvs.hq.bed') if $self->snv_result;
}

1;
