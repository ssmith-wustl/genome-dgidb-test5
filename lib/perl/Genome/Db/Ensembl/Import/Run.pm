package Genome::Db::Ensembl::Import::Run;

use strict;
use warnings;
use Genome;

class Genome::Db::Ensembl::Import::Run {
    is => 'Command::V2',
    doc => 'Import a version of ensembl annotation',
    has => [
        data_set => {
            is => 'Text',
            doc => 'Ensembl data set to import (ex )',
            is_optional => 1,
        },
        imported_annotation_build => {
            is => 'Genome::Model::Build::ImportedAnnotation',
            doc => 'Imported anntation build',
        },
    ],
};

sub help_brief {
}

sub help_detail {
    return <<EOS
EOS
}

sub execute {
    my $self = shift;
    my $data_set = $self->data_set;
    my $build = $self->imported_annotation_build;
    my $data_directory = $build->data_directory;
    my $version= $build->version;
    my $species_name = $build->species_name;
    my $reference_build_id = $build->reference_sequence_id;
    
    #download the Ensembl API to $build->data_directory
    my $api_version = $self->ensembl_version_string($version);
    my $api_cmd = Genome::Db::Ensembl::Import::InstallEnsemblApi->execute(
        version => $api_version,
        output_directory => $data_directory,
    );
    
    my $annotation_data_directory = join('/', $data_directory, 'annotation_data');
    unless(-d $annotation_data_directory){
        Genome::Sys->create_directory($annotation_data_directory);
        unless (-d $annotation_data_directory) {
            $self->error_message("Failed to create new annotation data dir: " . $annotation_data_directory);
            return;
        }
    }

    my $log_file = $data_directory . "/" . 'ensembl_import.log';
    my $dump_file = $data_directory . "/" . 'ensembl_import.dump';
    
    my ($host, $user, $pass) = $self->get_ensembl_info($version);
    
    my $command = join(" " , 
        "genome db ensembl import create-annotation-structures", 
        "--data-directory $annotation_data_directory",
        "--version $version",
        "--host $host",
        "--user $user",
        ($pass ? "--pass $pass" : ''),
        "--species $species_name",
        "--data-set $data_set", 
        "--reference-build-id $reference_build_id",
        "--log-file $log_file",
        "--dump-file $dump_file");
    $build->prepend_api_path_and_execute(cmd => $command);

}

#TODO: make this connect to a public ensembl DB if the environment variables aren't set
sub get_ensembl_info {
    my $self = shift;
    my $version = shift;
    my ($eversion,$ncbiversion) = split(/_/,$version);

    my $host = defined $ENV{GENOME_DB_ENSEMBL_HOST} ? $ENV{GENOME_DB_ENSEMBL_HOST} : 'mysql1';
    my $user = defined $ENV{GENOME_DB_ENSEMBL_USER} ? $ENV{GENOME_DB_ENSEMBL_USER} : 'mse'; 
    my $password = defined $ENV{GENOME_DB_ENSEMBL_PASSWORD} ? $ENV{GENOME_DB_ENSEMBL_PASSWORD} : undef;

    return ($host, $user, $password);
}

sub ensembl_version_string {
    my $self = shift;
    my $ensembl = shift;

    # <ens version>_<ncbi build vers><letter>
    # 52_36n

    my ( $e_version_number, $ncbi_build ) = split( /_/x, $ensembl );
    return $e_version_number;
}

1;
