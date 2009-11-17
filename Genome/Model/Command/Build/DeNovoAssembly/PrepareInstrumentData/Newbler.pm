package Genome::Model::Command::Build::DeNovoAssembly::PrepareInstrumentData::Newbler;

use strict;
use warnings;

use Genome;
use Data::Dumper;



class Genome::Model::Command::Build::DeNovoAssembly::PrepareInstrumentData::Newbler {
    is => 'Genome::Model::Command::Build::DeNovoAssembly::PrepareInstrumentData',
    has => [],
};


sub execute {
    my $self = shift;

    my $model = $self->model;
    my $build = $self->build;

    my @instrument_data = $self->model->instrument_data;

    unless (@instrument_data) {
	$self->error_message("Failed to get or no instrument data assigned to model");
	return;
    }

    foreach my $data (@instrument_data) {

	unless ($data->isa('Genome::InstrumentData::454')) {
	    $self->error_message("Found non-instrument data where only instrument data should be:\n".
		                  Data::Dumper::Dumper($data));
	    return;
	}

	unless (-e $data->fasta_file .'.cln') {
	    my $seq_clean =  Genome::Model::Tools::454::Seqclean->create(
	                                                                 in_fasta_file => $data->fasta_file,
	                                                                 seqclean_params => '-c 2',
	                                                                );
	    unless ($seq_clean->execute) {
		$self->error_message('Failed to run seqclean');
		return;
	    }
	}

	my $seq_clean_report = $data->fasta_file.'.cln';    
	unless (-s $seq_clean_report) {
	    $self->error_message('Can not find seqclean report '. $seq_clean_report .' or it is zero size');
	    return;
	}

	#TRIM READ SETS
	unless (-e $data->trimmed_sff_file) {
	    my %trimmer_params = (
	                          seqclean_report => $seq_clean_report,
			          in_sff_file => $data->sff_file,
			          out_sff_file => $data->trimmed_sff_file, #MOVE TO BUILD
			          version => $model->assembler_version,
			          version_subdirectory => $model->version_subdirectory,
                                 );
	    unless (Genome::Model::Tools::454::SffTrimWithSeqcleanReport->execute( %trimmer_params )) {
		$self->error_message("Failed to execute trim seq-clean tool with params:\n".
				     Data::Dumper::Dumper(%trimmer_params));
		return;
	    }
	}
    }

    return 1;
}

sub valid_params {
    my $params = {};
    return $params;
}

1;
