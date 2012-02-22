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
            default_value => 4.5,
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

    my $species_name = $build->species_name;
    unless (defined $species_name){
        $self->error_message('Could not get species name!');
        return;
    }

    my $name = ucfirst(lc($source));
    my $importer_class_name = join('::', 'Genome', 'Db', $name, 'Import', 'Run');
    #TODO: get the data_set in here
    my $cmd = $importer_class_name->execute(
        # data_set => '', 
        imported_annotation_build => $build,
    );

    my $interpro_cmd = Genome::Model::Tools::Annotate::ImportInterpro::Run->execute(
        reference_transcripts => join('/', $model->name, $version),
        interpro_version => $self->interpro_version, #TODO: update processing profiles
        log_file => join('/', $data_directory, 'interpro_log'),
    );
    $interpro_cmd->execute;

    my $tiering_cmd;
    my $annotation_directory = $build->_annotation_data_directory;
    my $bitmasks_directory = $annotation_directory."/tiering_bitmasks";
    unless ( -d $bitmasks_directory) {
        Genome::Sys->create_directory($bitmasks_directory);
        unless (-d $bitmasks_directory) {
            $self->error_message("Failed to create new build dir: " . $bitmasks_directory);
            return;
        }
    }
    my $bed_directory = $annotation_directory."/tiering_bed_files_v3";
    unless ( -d $bed_directory) {
        Genome::Sys->create_directory($bed_directory);
        unless (-d $bed_directory) {
            $self->error_message("Failed to create new build dir: " . $bed_directory);
            return;
        }
    }
    if ($species_name eq 'human') {
        $tiering_cmd = Genome::Model::Tools::FastTier::MakeTierBitmasks->create(
            output_directory => $annotation_directory."/tiering_bitmasks",
            reference_sequence => $build->reference_sequence->fasta_file,
            transcript_version => $build->version,
            annotation_model => $build->model,
            ucsc_directory => $build->reference_sequence->get_or_create_ucsc_tiering_directory,
        );
    }
    elsif ($species_name eq 'mouse') {
        $tiering_cmd = Genome::Model::Tools::FastTier::MakeMouseBitmasks->create(
            output_directory => $annotation_directory."/tiering_bitmasks",
            reference_sequence => $build->reference_sequence->fasta_file,
        );
    }

    if ($species_name eq 'human' or $species_name eq 'mouse') {
        $tiering_cmd->execute;
        foreach my $file ($tiering_cmd->tier1_output, $tiering_cmd->tier2_output, $tiering_cmd->tier3_output, $tiering_cmd->tier4_output) {
            my $bed_name = $file;
            $bed_name =~ s/tiering_bitmasks/tiering_bed_files_v3/;
            $bed_name =~ s/bitmask/bed/;
            my $convert_cmd = Genome::Model::Tools::FastTier::BitmaskToBed->create(
                output_file => $bed_name,
                bitmask => $file,
            );
        }
    }

    my $ucsc_directory = $annotation_directory."/ucsc_conservation";
    Genome::Sys->create_symlink($ucsc_directory, $build->reference_sequence->get_or_create_ucsc_conservation_directory); 

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
