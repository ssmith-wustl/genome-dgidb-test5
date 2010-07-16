package Genome::Model::Build::GenePrediction;

use strict;
use warnings;

use Genome;
use YAML;
use Carp;
use File::Basename;

class Genome::Model::Build::GenePrediction {
    is => 'Genome::Model::Build',
};

# Returns the location of the yaml file
sub yaml_file_path {
    my $self = shift;
    return $self->data_directory . "/config.yaml";
}

# Creates a yaml file containing all the various parameters needed by gene prediction
sub create_yaml_file {
    my $self = shift;
    my $model = $self->model;
    my $config_file_path = $self->yaml_file_path;
    $self->status_message("Creating yaml configuration file at $config_file_path");

    my ($contigs_file_name, $contigs_dir) = fileparse($model->contigs_file_location);
    my $locus_tag = $model->locus_id . $model->run_type;
    # TODO Could we just use the assembly model's name?
    my $assembly_name = ucfirst($model->organism_name) . '_' . $locus_tag . '.velv.amgap';
    # TODO What is this used for?
    my $org_dirname = substr(ucfirst($model->organism_name), 0, 1) .
                      substr($model->organism_name, index($model->organism_name, "_"));

    my %params = (
        acedb_version    => $model->acedb_version,
        assembly_name    => $assembly_name,
        assembly_version => $model->assembly_version,
        cell_type        => uc($model->cell_type),
        gram_stain       => $model->gram_stain,
        locus_id         => $model->locus_id,
        locus_tag        => $locus_tag,
        minimum_length   => $model->minimum_sequence_length,
        ncbi_taxonomy_id => $model->ncbi_taxonomy_id,
        nr_db            => $model->nr_database_location,
        org_dirname      => $org_dirname,
        organism_name    => ucfirst($model->organism_name),
        path             => $self->data_directory,
        pipe_version     => $model->pipeline_version,
        project_type     => $model->project_type,
        runner_count     => $model->runner_count,
        seq_file_dir     => $contigs_dir,
        seq_file_name    => $contigs_file_name,
        skip_acedb_parse => $model->skip_acedb_parse,
        use_local_nr     => $model->use_local_nr,
    );

    my $rv = YAML::DumpFile($config_file_path, %params);
    unless ($rv) {
        $self->error_message("Could not create config file at $config_file_path!");
        return;
    }

    return $config_file_path;
}

1;
