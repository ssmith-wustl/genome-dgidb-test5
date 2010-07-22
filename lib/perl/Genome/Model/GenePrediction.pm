package Genome::Model::GenePrediction;

use strict;
use warnings;

use Genome;

class Genome::Model::GenePrediction {
    is => 'Genome::Model',
    has => [
        # Processing profile parameters
        minimum_sequence_length => { 
            via => 'processing_profile', 
        },
        runner_count => { 
            via => 'processing_profile',
        },
        skip_acedb_parse => { 
            via => 'processing_profile',
        },
        skip_core_gene_check => {
            via => 'processing_profile',
        },
    ],
    has_many_optional => [
        inputs => {
            is => 'Genome::Model::Input',
            reverse_as => 'model',
            doc => 'Inputs assigned to the model',
        },
    ],
    has_optional => [
        contigs_file_location => {
            is => 'Path',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'contigs_file_location' ],
            doc => 'Path to the contigs file needed for prediction and merging',
        },
        dev => {
            is => 'Boolean',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'dev' ],
            doc => 'If set, dev databases are used instead of production databases',
        },
        run_type => {
            is => 'String', # TODO Does this affect processing? Why do we need to note it?
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'run_type' ],
            doc => 'A three letter identifier appended to locus id, (DFT, FNL, etc)',
        },
        assembly_version => {
            is => 'String', # TODO Can this be removed or derived from the assembly in some way?
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'assembly_version' ],
            doc => 'This notes the assembly version, but doesn\'t really seem to change...',
        },
        project_type => {
            is => 'String', # TODO What is this? Why do we need it?
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'project_type' ],
            doc => 'The type of project this data is being generated for (HGMI, for example)',
        },
        pipeline_version => {
            is => 'String', # TODO Can this be removed? Why do we need it?
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'pipeline_version' ],
            doc => 'Apparently, this notes the pipeline version.', 
        },
        acedb_version => {
            is => 'String', # TODO If we can figure out a way to automate switching to a new db, this can go away
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'acedb_version' ],
            doc => 'Notes the version of aceDB that results should be uploaded to',
        },
        nr_database_location => {
            is => 'Path', # TODO Once using local NR is fully tested and trusted, this param can be removed
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'nr_database_location' ],
            doc => 'The NR database that should be used by default, may be overridden by local copies',
        },
        use_local_nr => {
            is => 'Boolean',
            via => 'inputs',
            to => 'value_id',
            where => [ name => 'use_local_nr' ],
            doc => 'If set, local NR databases are used by blast jobs instead of accessing the default location',
        },
        gram_stain => {
            via => 'subject',
            to => 'gram_stain_category',
        },
        cell_type => {
            via => 'subject',
            to => 'domain',
        },
        ncbi_taxonomy_id => {
            via => 'subject',
            to => 'ncbi_taxon_id',
        },
        # The species latin name on some taxons includes a strain name, which needs to be removed
        organism_name => {
            calculate_from => ['subject'],
            calculate => q( 
                my $latin_name = $subject->species_latin_name;
                $latin_name =~ s/\s+/_/g; 
                my $first = index($latin_name, "_");
                my $second = index($latin_name, "_", $first + 1);
                return $latin_name if $second == -1;
                return substr($latin_name, 0, $second);
            ),
        },
        locus_id => {
            via => 'subject',
            to => 'locus_tag',
        },
    ],
};

# Every gene prediction model must have a linked de novo assembly model. The taxon is derived from
# the assembly model, and certain fields on the taxon must be filled in as well. Anything taken
# from the processing profile should be checked when the PP is created
sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_) or return;

    # Perform checks on the taxon
    my $base_error_msg = "Taxon with ID " . $self->subject_id; 
    unless (defined $self->gram_stain) {
        $self->error_message($base_error_msg . " does not have gram stain defined!");
        return;
    }

    unless (defined $self->locus_id) {
        $self->error_message($base_error_msg . " does not have locus tag defined!");
        return;
    }

    unless (defined $self->organism_name) {
        $self->error_message($base_error_msg . " does not have organism name defined!");
        return;
    }

    return $self;
}

1;

