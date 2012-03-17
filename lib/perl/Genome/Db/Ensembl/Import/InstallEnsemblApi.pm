package Genome::Db::Ensembl::Import::InstallEnsemblApi;

use strict;
use warnings;
use Genome;

class Genome::Db::Ensembl::Import::InstallEnsemblApi {
    is => 'Command::V2', 
    doc => '', 
    has => [
        version => {
            is => 'Text',
            doc => 'Version of ensembl API to install'
        },
        output_directory => {
            is => 'Path',
            doc => 'Directory to import ensembl API to',
        },
    ],
};

sub help_brief {

}

sub help_detail {

}

sub execute {
    my $self = shift;
    my $output_directory = $self->output_directory;
    my $version = $self->version;
    my $temp_directory_path = Genome::Sys->create_temp_directory;

    my @package_names = qw/ ensembl ensembl-compara ensembl-variation ensembl-functgenomics /;
    my $base_url = "'http://cvs.sanger.ac.uk/cgi-bin/viewvc.cgi/PACKAGENAME.tar.gz?root=ensembl&only_with_tag=branch-ensembl-VERSION&view=tar'";


    for my $package_name (@package_names){
        my $tar_url = $base_url;
        $tar_url =~ s/PACKAGENAME/$package_name/;
        $tar_url =~ s/VERSION/$version/;
        my $tar_file = join("/", $temp_directory_path, "$package_name.tar.gz");
        my $extracted_directory = join("/", $temp_directory_path, $package_name);
        my $wget_command = "wget $tar_url -O $tar_file";
        my $rv = Genome::Sys->shellcmd(cmd => $wget_command, output_files => [$tar_file]);
        unless($rv){
            $self->error_message("Failed to download $package_name"); 
            die($self->error_message);
        }

        my $extract_command = "tar -xzf $tar_file -C $temp_directory_path";
        $rv = Genome::Sys->shellcmd(cmd => $extract_command, input_files => [$tar_file], output_directories => [$extracted_directory]);
        unless($rv){
            $self->error_message("Failed to extract $tar_file"); 
            die($self->error_message);
        }

        my $mv_command = "mv $extracted_directory $output_directory";
        $rv = Genome::Sys->shellcmd(cmd => $mv_command, input_directories => [$extracted_directory], output_directories => [$output_directory]);
        unless($rv){
            $self->error_message("Failed to mv $extracted_directory to $output_directory"); 
            die($self->error_message);
        }
    }

    return 1;
    
}

1;
