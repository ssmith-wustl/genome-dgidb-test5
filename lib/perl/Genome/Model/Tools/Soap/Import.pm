package Genome::Model::Tools::Soap::Import;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';
require File::Basename;
require Genome::Model::Tools::Dacc::Download;

class Genome::Model::Tools::Soap::Import {
    is => 'Genome::Model::Tools::Soap',
    has => [
        version => {
            is => 'Text',
            doc => 'Version of Soap DeNovo to use',
            valid_values => [qw/ dacc /],
        },
        import_location => {
            is => 'Text',
            doc => 'The location of the assembly to import.',
        },
        output_dir_and_file_prefix => {
            is => 'Text',
            doc => 'Path and common prefix name for output files',
        },
    ],
};

sub help_brief {
    return 'Import a soap denovo assembly';
}

sub help_detail {
    return <<HELP;
    Import a soap denovo assembly. Currently only importing from the DACC.
HELP
}

sub execute {
    my $self = shift;

    $self->status_message('Import SOAP assembly from the DACC');

    my ($file_prefix, $output_dir) = File::Basename::fileparse($self->output_dir_and_file_prefix);
    if ( not -d $output_dir ) {
        $self->error_message("Invalid output directory: $output_dir does not exist");
        return;
    }
    my $edit_dir = $output_dir.'/edit_dir';
    mkdir $edit_dir if not -d $edit_dir;
    $self->status_message('Output directroy: '.$output_dir);
    $self->status_message('Edit directroy: '.$edit_dir);
    $self->status_message('File prefix: '.$file_prefix);

    my @center_names = (qw/ Baylor LANL /);
    my ($center_name) = grep { $file_prefix =~ /$_/ } @center_names;
    if ( not $center_name ) {
        $self->error_message("Cannot determine center name from file prefix: $file_prefix");
        return;
    }
    $self->status_message('Center name: '.$center_name);

    my $dacc_directory = $self->import_location;
    $self->status_message('DACC directory: '.$dacc_directory);
    my $dacc_downloader = Genome::Model::Tools::Dacc::Download->create(
        dacc_directory => $dacc_directory,
        destination => $edit_dir,
    );
    if ( not $dacc_downloader ) {
        $self->error_message('Cannot creat DACC downloader.');
        return;
    }
    $dacc_downloader->dump_status_messages(1);

    my %available_files_and_sizes = $dacc_downloader->available_files_and_sizes;
    if ( not %available_files_and_sizes ) {
        $self->error_message('No files found in DACC directory: '.$dacc_directory);
        return;
    }

    $self->status_message('Determining files to download');
    my %files_to_download;
    my @exts = (qw/ scafSeq agp contigs.fa scaffolds.fa /);
    for my $ext ( @exts ) {
        my @available_files = grep { m/\.$ext/ } keys %available_files_and_sizes;
        next if not @available_files;
        if ( @available_files == 1 ) {
            $files_to_download{$ext} = $available_files[0];
            next;
        }
        my ($available_pga_file) = grep { m/PGA/ } @available_files;
        if ( not $available_pga_file ) {
            $self->error_message("Found multiple files in dacc directory ($dacc_directory) for file ext ($ext), but one of them does not have PGA in the name. Files: @available_files");
            return;
        }
        $files_to_download{$ext} = $available_pga_file;
    }

    if ( not %files_to_download ) {
        $self->error_message("No files in dacc directory ($dacc_directory) matched the extensions that are suppossed to be downloaded: @exts");
        return;
    }
    my @files_to_download = keys %files_to_download;
    if ( keys %files_to_download != @exts ) {
        $self->error_message('Expected to find '.@exts.' files to download, but only found '.@files_to_download.": @files_to_download");
        return;
    }
    $self->status_message("Files to download: @files_to_download");

    $self->status_message("Executing downloader");
    $dacc_downloader->files(\@files_to_download);
    if ( not $dacc_downloader->execute ) {
        $self->error_message('DACC downloader failed to execute');
        return;
    }
    $self->status_message("Executing downloader...OK");

    my $from = $edit_dir.'/'.$files_to_download{scafSeq};
    my $size = -s $from;
    my $to = $output_dir.'/'.$files_to_download{scafSeq};
    $self->status_message("Move scafSeq file $from to $to");
    my $move = File::Copy::move($from, $to);
    if ( not $move ) {
        $self->error_message('Move failed: '.$!);
        return;
    }
    if ( -s $to != $size ) {
        $self->error_message("Move succeeded, but file ($files_to_download{scafSeq}) now has different size: $size <=> ".-s $to);
        return;
    }
    $self->status_message("Move agp file...OK");

    $self->status_message('Import SOAP assembly...OK');

    return 1;
}

1;

