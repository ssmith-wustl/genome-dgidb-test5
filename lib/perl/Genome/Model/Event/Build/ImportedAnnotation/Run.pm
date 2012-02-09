package Genome::Model::Event::Build::ImportedAnnotation::Run;

use strict;
use warnings;

use Genome;
use Carp;

class Genome::Model::Event::Build::ImportedAnnotation::Run {
    is => 'Genome::Model::Event',
 };

$Workflow::Simple::override_lsf_use=1;

sub sub_command_sort_position { 41 }

sub help_brief {
    "Build for imported annotation  models (not implemented yet => no op)"
}

sub help_synopsis {
    return <<"EOS"
genome-model build mymodel 
EOS
}

sub help_detail {
    return <<"EOS"
One build of a given imported annotation database
EOS
}

sub execute {
    my $self = shift;
    
    my $model = $self->model;
    my $build = $self->build;

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

    my $data_directory = $self->build->data_directory;
    unless (defined $data_directory){
        $self->error_message("Could not get data directory for build!");
        return;
    }
    unless (-d $data_directory){
        $self->create_directory($self->build->data_directory);
    }
    unless (-d $data_directory) {
        $self->error_message("Failed to create new build dir: " . $self->build->data_directory);
        return;
    }

    my $log_file = $data_directory . "/" . $source . "_import.log";
    my $dump_file = $data_directory . "/" . $source . "_import.dump";

    my ($host, $user, $pass) = $self->get_ensembl_info($version);

    my $annotation_data_source_directory = $build->annotation_data_source_directory;
    unless (defined $annotation_data_source_directory){
        $self->error_message("Could not determine annotation data source directory!");
        return;
    }

    my $command = Genome::Model::Tools::ImportAnnotation::Ensembl->create(
        data_directory  => $annotation_data_source_directory,
        version         => $version,
        host            => $host,
        user            => $user,
        pass            => $pass,
        species         => $model->species_name,
        log_file        => $log_file,
        dump_file       => $dump_file,
    );
    $command->execute;

    my $annotation_data_directory = $build->_annotation_data_directory;
    unless ($annotation_data_directory){
        $self->error_message("Could not get annotation data directory for build");
        return;
    }
    my $sym_rv = symlink $annotation_data_source_directory, $annotation_data_directory;
    unless ($sym_rv){
        $self->error_message("Could not create symlink from $annotation_data_source_directory to $annotation_data_directory");
        return;
    }

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

    unless(Genome::Model::Event::Build::ImportedAnnotation::CopyRibosomalGeneNames->execute(output_file => $build->_annotation_data_directory .'/RibosomalGeneNames.txt', species_name => $build->species_name)){
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
