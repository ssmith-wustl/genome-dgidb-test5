package Genome::InstrumentData::Command::Import::Microarray::IlluminaGenotypeArray;

use strict;
use warnings;

use Genome;

require File::Basename;
require File::Copy;
require IO::Dir;
require IO::File;

class Genome::InstrumentData::Command::Import::Microarray::IlluminaGenotypeArray {
    is  => 'Genome::InstrumentData::Command::Import::Microarray::Base',
    has => [
        sequencing_platform => { is => 'Text', is_param => 0, is_constant => 1, value => 'illumina', },
    ],
    doc => 'create an instrument data for a microarray',
};

sub _resolve_unsorted_genotype_file {
    my $self = shift;

    my $data_directory = $self->_instrument_data->data_directory;
    my $unsorted_genotype_file = $self->_instrument_data->data_directory.'/'.$self->sample->name.'.genotype';
    return $unsorted_genotype_file if -s $unsorted_genotype_file;
    $self->status_message('Generate unsorted genotype file: '.$unsorted_genotype_file);
    unlink $unsorted_genotype_file if -e $unsorted_genotype_file;

    my ($call_file, $manifest_file) = $self->_resolve_call_and_manifest_files;
    if ( not $call_file ) {
        $self->error_message('Failed to generate genotype file. No call file was found');
        return;
    }
    $self->status_message("Call file: ".$call_file);
    if ( not $manifest_file ) {
        $self->error_message('Failed to generate genotype file. No manifest file was found');
        return;
    }
    $self->status_message("Manifest: ".$manifest_file);

    $self->status_message('Create unsorted genotype file');
    my $tool = Genome::Model::Tools::Array::CreateGenotypesFromIlluminaCalls->create(  
        sample_name => $self->sample->name,
        call_file => $call_file,
        illumina_manifest_file => $manifest_file,
        output_path => $data_directory, 
    );
    if ( not $tool ) {
        $self->error_message('Failed to create "create genotype file from illumina calls" tool');
        return;
    }
    $tool->dump_status_messages(1);
    if ( not $tool->execute ) {
        $self->error_message('Failed to execute "create genotype file from illumina calls" tool');
        return;
    }

    $self->status_message('Create unsorted genotype file...OK');

    return $unsorted_genotype_file;
}

sub _resolve_call_and_manifest_files {
    my $self = shift;

    my $data_directory = $self->_instrument_data->data_directory;
    my $io_dir = IO::Dir->new($data_directory);
    if ( not $io_dir ) {
        $self->error_message("Failed to open instrument data directory ($data_directory): $!");
        return;
    }
    $io_dir->read; $io_dir->read; # . & ..

    my ($call_file, $manifest_file);
    while ( my $file = $io_dir->read ) {
        if ( -d "$data_directory/$file" or -b "$data_directory/$file" ) {
            next;
        }

        my $fh = IO::File->new("$data_directory/$file", "r");
        unless(defined($fh)) {
            print "could not open ".$file.". Skipping this file.\n";
            next;
        }

        #test to see if files for illumina genotype array are present
        my $count = 0;
        my $match;
        while ($count < 10) {
            my $line = $fh->getline; 
            unless(defined($line)) {
                last;
            }
            if ($line =~ /Assay/) {
                $match = $&;
                last;
            }
            if ($line =~ /Data/) {
                $match = $&;
                last;
            }
            $count++;
        }
        $fh->close;

        if (defined($match)) {
            if ($match eq "Assay") {
                $manifest_file = $data_directory."/".$file;
            } elsif ($match eq "Data") {
                $call_file = $data_directory."/".$file;
            }
        }

        if ( $manifest_file and $call_file ) {
            #files are present, deciding this is an illumina genotype array
            $self->status_message("Input files determined to be Illumina Genotype Array");
            last;
        }
    }

    return ($call_file, $manifest_file);
}

1;

