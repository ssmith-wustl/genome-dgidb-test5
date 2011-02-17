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
    has_optional => {
        indel_feature_list => {
            is => 'Genome::FeatureList',
            id_by => 'indel_feature_list_id',
        },
        indel_feature_list_id => {
            via => 'inputs',
            is => 'Text',
            to => 'value_id',
            where => [
                name => 'indel_feature_list_id',
                value_class_name => 'Genome::FeatureList'
            ], 
            is_mutable => 1,
            doc => 'The feature list containing the imported variations',
        },
        snv_feature_list => {
            is => 'Genome::FeatureList',
            id_by => 'snv_feature_list_id',
        },
        snv_feature_list_id => {
            via => 'inputs',
            is => 'Text',
            to => 'value_id',
            where => [
                name => 'snv_feature_list_id',
                value_class_name => 'Genome::FeatureList'
            ], 
            is_mutable => 1,
            doc => 'The feature list containing the imported variations',
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

    return $self->snv_feature_list->file_path if $self->snv_feature_list;
}

1;
