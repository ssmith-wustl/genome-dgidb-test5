package Genome::Model::Build::DeNovoAssembly;

use strict;
use warnings;

use Genome;

class Genome::Model::Build::DeNovoAssembly {
    is => 'Genome::Model::Build',
};

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    unless ( $self->model->type_name eq 'de novo assembly' ) {
        $self->error_message( 
            sprintf(
                'Incompatible model type (%s) to build as an de novo assembly',
                $self->model->type_name,
            )
        );
        $self->delete;
        return;
    }

    mkdir $self->data_directory unless -d $self->data_directory;
    
    return $self;
}
    
sub velvet_fastq_file {
    return $_[0]->data_directory.'/velvet.fastq';
}

sub assembly_directory {
    return $_[0]->data_directory.'/assembly';
}

sub sff_directory {
    return $_[0]->data_directory.'/sff';
}

#NEWBLER SPECIFIC
sub fasta_file {
    my $self = shift;
    my @instrument_data = $self->model->instrument_data;
    #SINGULAR FOR NOW .. NEED TO GET IT TO WORK FOR MULTIPLE INPUTS
    my $fasta = $instrument_data[0]->fasta_file;
    unless ($fasta) {
	$self->error_message("Instrument data does not have a fasta file");
	return;
    }
    #COPY THIS FASTA TO BUILD INPUT_DATA_DIRECTORY
    File::Copy::copy ($fasta, $self->input_data_directory);
    #RENAME THIS FASTA TO SFF_NAME.FA ??
    #RETURN TO PREPARE-INSTRUMENT DATA FOR CLEANING
    return 1;
}

sub input_data_directory {
    my $self = shift;
    mkdir $self->data_directory.'/input_data' unless
	-d $self->data_directory.'/input_data';
    return $self->data_directory.'/input_data';
}



1;

#$HeadURL: svn+ssh://svn/srv/svn/gscpan/perl_modules/trunk/Genome/Model/Build/DeNovoAssembly.pm $
#$Id: DeNovoAssembly.pm 47126 2009-05-21 21:59:11Z ebelter $
