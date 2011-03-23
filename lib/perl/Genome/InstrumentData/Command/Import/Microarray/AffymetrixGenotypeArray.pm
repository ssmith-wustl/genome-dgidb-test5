package Genome::InstrumentData::Command::Import::Microarray::AffymetrixGenotypeArray;

use strict;
use warnings;

use Genome;
use File::Copy;
use File::Copy::Recursive;
use File::Basename;
use IO::Handle;

class Genome::InstrumentData::Command::Import::Microarray::AffymetrixGenotypeArray {
    is  => 'Genome::InstrumentData::Command::Import::Microarray::Base',
    has => [
        annotation_file => {
            is => 'Text',
            doc => 'The absolute path to the Affy annotation file. If unspecified, the importer will try to determine which is best based on sample_name.',
            is_optional => 1,
        },
        sequencing_platform => { is => 'Text', is_param => 0, is_constant => 1, value => 'affymetrix', },
    ],
};

sub process_imported_files {
    my $self = shift;

    my $genotype_file = $self->_instrument_data->genotype_microarray_file_for_reference_sequence_build($self->reference_sequence_build);
    if ( -s $genotype_file ) {
        # Validate?
        $self->status_message('Genotype file exists: '.$genotype_file);
        return 1;
    }
    $self->status_message('Generate genotype file: '.$genotype_file);

    my $call_file = $self->_resolve_call_file;
    return if not $call_file;

    my $annotation_file = $self->_resolve_annotation_file;
    return if not $annotation_file;

    my $tool = Genome::Model::Tools::Array::CreateGenotypesFromAffyCalls->create(  
        call_file =>  $call_file,
        annotation_file => $annotation_file,
        output_filename => $genotype_file,
    );
    if ( not $tool ) {
        $self->error_message('Failed to create "create genotypes from illumina calls" tool');
        return;
    }
    if ( not $tool->execute ) {
        $self->error_message('Failed to execute "create genotypes from illumina calls" tool');
        return;
    }

    if ( not -s $genotype_file ) {
        $self->error_message('Successfully executed "create genotypes from illumina calls" tool, but genotype file does not exist');
        return;
    }

    $self->status_message('Generate genotype file...OK');

    return 1;
}

sub _resolve_call_file {
    my $self = shift;

    $self->status_message('Resolve call file');

    my $data_directory = $self->_instrument_data->data_directory;
    my @files = glob($data_directory."/*");
    my $call_file;
    if ( not @files ) {
        $self->error_message('No files in instrument data directory: '.$self->_instrument_data->data_directory);
        return;
    }
    elsif ( @files == 1 ) {
        $call_file = $files[0];
    }
    else {
        for (@files) {
            unless( $_ =~ /250(k|K)/ ) {
                $self->error_message("found multiple files, but one was not 250K type.");
                die $self->error_message;
            }

        }
        $call_file = $data_directory.'/cat_call_file.txt';
        for (@files) {
            system("cat ".$_." >>".$call_file);
        }
    }

    $self->status_message('Call file: '.$call_file);

    return $call_file;
}

sub _resolve_annotation_file {
    my $self = shift;

    $self->status_message('Resolve annotation file');

    my $annotation_file = $self->annotation_file;
    if ( not defined $annotation_file ) {
        if($self->library->sample_name =~ /^(H_LS|H_LR)/){
            $annotation_file = "/gscmnt/sata160/info/medseq/tcga/GenomeWideSNP_6.na31.annot.csv";
            $self->status_message("H_LS or H_LR project detected, using annotation file with build37 coordinates.");
        } else {
            $annotation_file = "/gscmnt/sata160/info/medseq/tcga/GenomeWideSNP_6.na28.annot.csv";
            $self->status_message("Using annotation file with build36 coordinates.");
        }
        $self->annotation_file($annotation_file);
    }

    $self->status_message('Annotation file: '.$annotation_file);

    if ( not -s $annotation_file ){
        $self->error_message("Annotation file does not exist");
        return;
    }

    return $annotation_file;
}

1;

