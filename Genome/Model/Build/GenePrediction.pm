package Genome::Model::Build::GenePrediction;

use strict;
use warnings;

use Genome;
use YAML;
use Carp;

class Genome::Model::Build::GenePrediction {
    is => 'Genome::Model::Build',
};


sub yaml_file
{
    my $self = shift;
    #$self->status_message(" brev orgname " . $self->model->brev_orgname);
    return $self->data_directory."/". $self->model->brev_orgname.".yaml";

}

sub _create_yaml_file
{
    # build out the yaml file that 'gmt hgmi hap' consumes.
    my $self = shift;
    my $config;
    my $model = $self->model;

#    $self->status_message("using imported assembly model id " . $model->assembly_model);
#    my $imported_assembly = Genome::Model->get($model->assembly_model);
    # most of this stuff could probably be moved else where
    my $imported_assembly_link = Genome::Model::Link->get(to_model_id => $model->id);
    unless($imported_assembly_link) {
        $self->error_message("can't get assembly model link for ". $model->id);
        croak;
    }
    my $imported_assembly = $imported_assembly_link->from_model;

    unless($imported_assembly) {
        $self->error_message("can't get model for imported assembly model");
        croak;
    }
    $self->status_message("using imported assembly model id " . $imported_assembly->id);
    my $sample = Genome::Sample->get($imported_assembly->subject_id);
    unless($sample) {
        $self->error_message("can't get sample for subject id \"" . $imported_assembly->subject_id . "\"");
        croak;
    }
    my $taxon = Genome::Taxon->get($sample->taxon_id);
    unless($taxon) {
        $self->error_message("can't get taxon for taxon id \"" . $sample->taxon_id . "\"");
        croak;
    }

    if(!defined($taxon->locus_tag)) 
    {
        $self->error_message("locus tag is NULL in gsc.organism_taxon.  please update.");
        croak;
    }
    # locus_tag/id
    #$self->locus_id = ($taxon->locus_tag);
    my $locus_id = $taxon->locus_tag;
    # organism name and
    # org dir name.
    #$self->organism_name( join('_',(split(/ /,$taxon->species_name))[0,1]) );
    my $organism_name = join('_',(split(/ /,$taxon->species_name))[0,1]) ;
    my @org_slices = (split(/ /,$taxon->species_name))[0,1];
    $org_slices[0] = substr($org_slices[0],0,1);
    #my $self->brev_orgname( $org_slices[0]."_".$org_slices[1]);
    my $brev_orgname = $org_slices[0]."_".$org_slices[1];
    $self->model->brev_orgname($brev_orgname);
    # seq dir and
    # assembly name
    my $directory = undef;
    my $ia_build = $imported_assembly->last_succeeded_build;
#    my $wanted = sub { if($_ eq 'contigs.bases') { $directory = $File::Find::dir;
#                                                   print STDERR $directory,"\n"; } };
    File::Find::find(sub { if($_ eq 'contigs.bases') {$directory = $File::Find::dir;} },
                     $ia_build->data_directory);
    if(!defined($directory)) {
        croak "can't find contigs.bases in imported assembly's datadirectory ". $ia_build->data_directory;
    }
    #$self->seq_file_dir($directory);
    my $seq_file_dir = $directory;
    #$self->assembly_name($imported_assembly->name.".amgap");  
    my $assembly_name = $imported_assembly->name.".amgap";  
    #$config->{path}             = $model->path; 
    $config->{path}             = $self->data_directory;
    $config->{org_dirname}      = $model->brev_orgname; 
    $config->{assembly_name}    = $assembly_name; 
    $config->{assembly_version} = $model->assembly_version; 
    $config->{pipe_version}     = $model->pipeline_version; 
    $config->{cell_type}        = $model->cell_type; 
    #$config->{seq_file_name}    = $model->seq_file_name; 
    $config->{seq_file_name}    = "contigs.bases";
    $config->{seq_file_dir}     = $seq_file_dir; 
    $config->{minimum_length}   = $model->minimum_seq_length; 

    # add on the DFT/FNL/MSI...
    $config->{locus_tag} = $locus_id . $model->draft;

    $config->{acedb_version}           = $model->acedb_version; 
    $config->{locus_id}                = $locus_id;
    $config->{organism_name}           = $organism_name; 
    $config->{runner_count}            = $model->runner_count; 
    $config->{project_type}            = $model->project_type; 
    $config->{gram_stain}              = $model->gram_stain; 
    $config->{ncbi_taxonomy_id}        = $model->ncbi_taxonomy_id; 
    $config->{predict_script_location} = $model->predict_script_location; 
    $config->{merge_script_location}   = $model->merge_script_location; 
    $config->{skip_acedb_parse}        = $model->skip_acedb_parse; 
    $config->{finish_script_location}  = $model->finish_script_location; 

    my $yaml_file = $self->yaml_file; # how should this be named?
    my $rv = YAML::DumpFile($yaml_file, $config);
    unless($rv)
    {
        $self->error_message("couldn't write out YAML file: ". $yaml_file);
        croak;
    }
    return $yaml_file;
}


#sub get_taxon_details
#{
#    my $self = shift;
#    my $model = $self->model;
#    my $imported_assembly = Genome::Model->get($model->assembly_model);
#    my $sample = Genome::Sample->get($imported_assembly->subject_id);
#    my $taxon = Genome::Taxon->get($sample->taxon_id);
#    if(!defined($taxon->locus_tag)) 
#    {
#        $self->error_message("locus tag is NULL in gsc.organism_taxon.  please update.");
#        croak;
#    }
#    # locus_tag/id
#    $self->locus_id = ($taxon->locus_tag);
#
#    # organism name and
#    # org dir name.
#    $self->organism_name( join('_',(split(/ /,$taxon->species_name))[0,1]) );
#    my @org_slices = (split(/ /,$taxon->species_name))[0,1];
#    $org_slices[0] = substr($org_slices[0],0,1);
#    $self->brev_orgname( $org_slices[0]."_".$org_slices[1]);
#    # seq dir and
#    # assembly name
#    my $directory = undef;
#    my $wanted = sub { if($_ eq 'contigs.bases') { $directory = $File::Find::dir; } };
#    find($wanted, $self->data_directory);
#    if(!defined($directory)) {
#        croak "can't find contigs.bases in imported assembly's datadirectory";
#    }
#    $self->seq_file_dir($directory);
#    $self->assembly_name($imported_assembly->name.".amgap");  
#    return 1;
#}

1;
