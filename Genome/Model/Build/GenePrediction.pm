package Genome::Model::Build::GenePrediction;

use strict;
use warnings;

use Genome;
use YAML;
use Carp;

class Genome::Model::Build::GenePrediction {
    is => 'Genome::Model::Build',
};

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);


    unless( -f $self->yaml_file() )
    {
        $self->status_message("YAML file exists");
        $self->_create_yaml_file();
    }

#    unless ($self->model->type_name eq 'imported assembly') {
#	$self->error_message("Model type must be imported assembly, not ".$self->model_type_name);
#	$self->delete;
#	return;
#    }

#    unless (-d $self->model->data_directory) {
#	$self->error_message("Failed to find assembly directory: ".$self->model->data_directory);
#	return;
#    }

#    $self->status_message("Your assembly has been tracked successfully");

    return $self;
}

sub yaml_file
{
    my $self = shift;
    return $self->data_directory."/". $self->model->brev_orgname.".yaml";

}

sub _create_yaml_file
{
    # build out the yaml file that 'gmt hgmi hap' consumes.
    my $self = shift;
    my $yaml_file = $self->yaml_file; # how should this be named?
    my $config;
    my $model = $self->model;

    $config->{path}             = $model->path; 
    $config->{org_dirname}      = $model->brev_orgname; 
    $config->{assembly_name}    = $model->assembly_name; 
    $config->{assembly_version} = $model->assembly_version; 
    $config->{pipe_version}     = $model->pipe_version; 
    $config->{cell_type}        = $model->cell_type; 
    $config->{seq_file_name}    = $model->seq_file_name; 
    $config->{seq_file_dir}     = $model->seq_file_dir; 
    $config->{minimum_length}   = $model->minimum_length; 

    # add on the DFT/FNL/MSI...
    $config->{locus_tag} = $model->locus_id . $model->draft;

    $config->{acedb_version}           = $model->acedb_version; 
    $config->{locus_id}                = $model->locus_id;
    $config->{organism_name}           = $model->organism_name; 
    $config->{runner_count}            = $model->runner_count; 
    $config->{project_type}            = $model->project_type; 
    $config->{gram_stain}              = $model->gram_stain; 
    $config->{ncbi_taxonomy_id}        = $model->ncbi_taxonomy_id; 
    $config->{predict_script_location} = $model->predict_script_location; 
    $config->{merge_script_location}   = $model->merge_script_location; 
    $config->{skip_acedb_parse}        = $model->skip_acedb_parse; 
    $config->{finish_script_location}  = $model->finish_script_location; 

    my $rv = DumpFile($yaml_file, $config);
    unless($rv)
    {
        $self->error_message("couldn't write out YAML file: ". $yaml_file);
        croak;
    }
    return $yaml_file;
}

1;
