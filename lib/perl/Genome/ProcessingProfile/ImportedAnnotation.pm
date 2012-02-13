package Genome::ProcessingProfile::ImportedAnnotation;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::ImportedAnnotation{
    is => 'Genome::ProcessingProfile',
    has_param => [
        annotation_source => {
            is_optional => 0,
            doc => 'Where the annotation comes from (ensembl, genbank, etc.) This value is "combined-annotation" for a combined-annotation model',
        },
        interpro_version => {
            is_optional => 0,
            doc => 'Version of interpro used to import interpro results', 
        }
    ],
    
};

sub _execute_build{
    my $self = shift;
    my $build = shift;
    my $model = $build->model;

    my $source = $model->annotation_source;
    unless (defined $source){
        $self->error_message("Could not get imported annotation source!");
        return;
    }
    unless ($source =~ /^ensembl$/i) {
        $self->error_message("$source is not a valid annotation data source");
        return;
    }

    my $version = $build->version;
    unless (defined $version){
        $self->error_message("Could not get build version!");
        return;
    }

    my $data_directory = $build->data_directory;
    unless (defined $data_directory){
        $self->error_message("Could not get data directory for build!");
        return;
    }
    unless (-d $data_directory){
        Genome::Sys->create_directory($build->data_directory);
        unless (-d $data_directory) {
            $self->error_message("Failed to create new build dir: " . $build->data_directory);
            return;
        }
    }
    unless(-d $build->_annotation_data_directory){
        Genome::Sys->create_directory($build->_annotation_data_directory);
        unless (-d $build->_annotation_data_directory) {
            $self->error_message("Failed to create new annotation data dir: " . $build->_annotation_data_directory);
            return;
        }
    }

    my $log_file = $data_directory . "/" . $source . "_import.log";
    my $dump_file = $data_directory . "/" . $source . "_import.dump";

    my ($host, $user, $pass) = $self->get_ensembl_info($version);

    my $command = Genome::Model::Tools::ImportAnnotation::Ensembl->create(
        data_directory  => $build->_annotation_data_directory,
        version         => $version,
        host            => $host,
        user            => $user,
        pass            => $pass,
        species         => $model->species_name,
        log_file        => $log_file,
        dump_file       => $dump_file,
    );
    $command->execute;

    #TODO: import interpro
    my $interpro_cmd = Genome::Model::Tools::Annotate::ImportInterpro::Run->exectue(
        reference_transcripts => join('/', $model->name, $version),
        interpro_version => $self->interpro_version, #TODO: update processing profiles
        log_file => join('/', $data_directory, 'interpro_log'),
    );
    $interpro_cmd->execute;

    #TODO: update the annotation data to Tony's format using the 2 scripts
    #TODO: generate tiering files?   

    #TODO: get the RibosomalGeneNames.txt into the annotation_data_directory
    #generate the rna seq files
    $self->generate_rna_seq_files($build);

    #Make ROI FeatureList
    $build->get_or_create_roi_bed;

    return 1;
}

sub get_ensembl_info {
    my $self = shift;
    my $version = shift;
    my ($eversion,$ncbiversion) = split(/_/,$version);
    my $path = "/gsc/scripts/share/ensembl-".$eversion;

    unless(-d $path) {
        die "$path  does not exist, is $eversion for ensembl installed?";
    }

    return ("mysql1","mse",undef); # no pass word needed here. all else const
}

sub generate_rna_seq_files {
    my $self = shift;
    my $build = shift;

    unless(Genome::Model::ImportedAnnotation::Command::CopyRibosomalGeneNames->execute(output_file => $build->_annotation_data_directory .'/RibosomalGeneNames.txt', species_name => $build->species_name)){
        $self->error_message("Failed to generate the ribosomal gene name file!");
        return;
    }

    unless($build->generate_RNA_annotation_files('gtf', $build->reference_sequence_id)){
        $self->error_message("Failed to generate RNA Seq files!");
        return;
    }

    return 1;
}

sub calculate_snapshot_date {
    my ($self, $genbank_file) = @_;
    my $output = `ls -l $genbank_file`;
    my @parts = split(" ", $output);
    my $date = $parts[5];
    return $date;
}

1;
