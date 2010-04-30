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
            is => 'String',
            via => 'inputs',
        },
        brev_orgname => {
            is => 'String',
            via => 'inputs',
        },
        organism_name => {
            is => 'String',
            via => 'inputs',
        },
        ncbi_taxonomy_id => {
            is => 'Integer',
            via => 'inputs',
            is_optional => 1,
        }, 
        seq_file_name => {
            is => 'String',
            via => 'inputs',
        },
        seq_file_dir => {
            is => 'String',
            via => 'inputs',
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

