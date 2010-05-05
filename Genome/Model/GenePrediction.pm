package Genome::Model::GenePrediction;

use strict;
use warnings;

use Genome;
use File::Slurp;
use YAML qw( LoadFile DumpFile );


class Genome::Model::GenePrediction {
    is => 'Genome::Model',
    has => [
        locus_id => {
#            is => 'String',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'locus_id' ,value_class_name=>'UR::Value'],
            is_mutable => 1,
        },
        brev_orgname => {
#            is => 'String',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'brev_orgname',value_class_name=>'UR::Value' ],
            is_mutable => 1,
        },
        assembly_name => {
#            is => 'String',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'assembly_name',value_class_name=>'UR::Value' ],
            is_mutable => 1,
        },
        organism_name => {
#            is => 'String',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'organism_name',value_class_name=>'UR::Value' ],
            is_mutable => 1,
        },
        ncbi_taxonomy_id => {
#            is => 'Integer',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'ncbi_taxonomy_id',value_class_name=>'UR::Value' ],
            is_mutable => 1,
            is_optional => 1,
        }, 
        seq_file_name => {
#            is => 'String',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'seq_file_name',value_class_name=>'UR::Value' ],
            is_mutable => 1,
        },
        seq_file_dir => {
#            is => 'String',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'seq_file_dir',value_class_name=>'UR::Value' ],
            is_mutable => 1,
        },
        iteration => {
#            is => 'Integer',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'iteration',value_class_name=>'UR::Value' ],
            is_mutable => 1,
            is_optional => 1,
        },
        # all the stuff from the processing profile:
        cell_type => { via => 'processing_profile' },
        draft => { via => 'processing_profile' },
        path => { via => 'processing_profile' },
        assembly_version => { via => 'processing_profile' },
        pipeline_version => { via => 'processing_profile' },
        minimum_seq_length => { via => 'processing_profile' },
        acedb_version => { via => 'processing_profile' },
        project_type => { via => 'processing_profile' },
        runner_count => { via => 'processing_profile' },
        gram_stain => { via => 'processing_profile' },
        predict_script_location => { via => 'processing_profile' },
        merge_script_location => { via => 'processing_profile' },
        finish_script_location => { via => 'processing_profile' },
        skip_acedb_parse => { via => 'processing_profile' },

    ],
    has_optional => [
         assembly_model_links => { 
             is => 'Genome::Model::Link', 
             reverse_as => 'to_model', 
             where => [ role => 'assembly'], is_many => 1,
             doc => '' },
         assmebly_model => { 
             is => 'Genome::Model', 
             via => 'assembly_model_links', to => 'from_model', 
             doc => '' },
    ],
};


# do we need anything here?

1;

