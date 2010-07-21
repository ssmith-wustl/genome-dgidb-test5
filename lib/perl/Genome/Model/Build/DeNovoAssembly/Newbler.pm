package Genome::Model::Build::DeNovoAssembly::Newbler;

use strict;
use warnings;

use Genome;

require Carp;
use Data::Dumper 'Dumper';
use Regexp::Common;

class Genome::Model::Build::DeNovoAssembly::Newbler {
    is => 'Genome::Model::Build::DeNovoAssembly',
};

#< Files / Dirs >#
sub assembly_directory {
    return $_[0]->data_directory.'/assembly';
}

sub sff_directory {
    return $_[0]->data_directory.'/sff';
}

sub input_fastas {
    my $self = shift;
    my @files;
    foreach (glob($self->data_directory."/*fasta.gz")) {
	#make sure qual file exists for the fasta
	my ($qual_file) = $_ =~ s/\.gz$/\.qual\.gz/;
	next unless -s $qual_file;
	push @files, $_;
    }
    
    return @files;
}

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
#<>#

#< Metrics >#
sub set_metrcs {
    my  $self = shift;

    # FIXME
    Carp::Confess("FIXME - Not set metrics implemented for newbler assemblies!!");
    
    return 1;
}
#<>#

1;

#$HeadURL$
#$Id$
