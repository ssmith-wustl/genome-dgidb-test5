package Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData::Newbler;

use strict;
use warnings;

use Genome;

class Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData::Newbler {
    is => 'Genome::Model::Event::Build::DeNovoAssembly::PrepareInstrumentData',
    has => [],
};


sub execute {
    my $self = shift;
    
    my $ret = $self->create;
    $self->error_message("There was an error in object creation") and return unless $ret;


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

    return $self->pre_process;
}

sub pre_process {
    my $self = shift;

    my $model = $self->model;
    my $build = $self->build;

#   my $instrument_data = $self->instrument_data; #NOT DEFINED

    my $assembly_directory = $build->assembly_directory;
    my $sff_directory = $build->sff_directory;

    unless (-d $assembly_directory && -d $sff_directory) {
    	my %new_assembly_params = (
                                   dir => $build->data_directory,
                                   version => $model->assembler_version,
                                   version_subdirectory=> $model->version_subdirectory,
	                          );
        my $new_assembly = Genome::Model::Tools::454::Newbler::NewAssembly->create( %new_assembly_params );
        unless ($new_assembly->execute) {
            # May need to add locking to prevent more than one event from creating project
            # Currently just double check that the project still doesn't exist after a few seconds
            sleep 5;
            unless (-d $assembly_directory && -d $sff_directory) {
                $self->error_message("Failed to create new assembly '$assembly_directory'");
                return;
            }
        }
        chmod 02775, $assembly_directory;
        chmod 02775, $sff_directory;
    }

    my @instrument_data = $model->instrument_data;
    unless (@instrument_data) {
	$self->error_message("Failed to get or no instrument data assigned to model");
	return;
    }
    foreach my $data (@instrument_data) {

	my $sff_file = ($model->read_trimmer_name) ?
#	$instrument_data->trimmed_sff_file : $instrument_data->sff_file;
	    $data->trimmer_sff_file : $data->sff_file;

	unless (-s $sff_file) {
	    print $self->error_message('non-existent or zero size sff file '. $sff_file);
	    return;
	}

	my %add_run_params = (
			       dir => $build->data_directory,
			       runs => [$sff_file],
#			       is_paired_end => $self->instrument_data->is_paired_end,
	                       is_paired_end => $data->is_paired_end,
			       version => $model->assembler_version,
			       version_subdirectory=> $model->version_subdirectory,
	                     );

	my $add_run = Genome::Model::Tools::454::Newbler::AddRun->create( %add_run_params );
	unless ($add_run->execute) {
	    $self->error_message("Failed to add run to project $assembly_directory with params:\n".
				 Data::Dumper::Dumper(%add_run_params));
	    return;
	}
    }
    return $self->verify_successful_completion;
}

sub verify_successful_completion {
    my $self = shift;

    my $build = $self->build;

    unless (-d $build->assembly_directory) {
        $self->error_message('Failed to create assembly directory: '. $build->assembly_directory);
        return;
    }
    unless (-d $build->sff_directory) {
        $self->error_message('Failed to create sff directory: '. $build->sff_directory);
        return;
    }
#    unless (-l $self->sff_link ) {
#        $self->error_message('Symlink '. $self->sff_link .' not created for newbler project');
#        return;
#    }
    unless ($self->created_all_sff_links) {
	$self->error_message("Failed to create all sff links");
	return;
    }
    return 1;
}

#sub sff_link {
sub created_all_sff_links {    
    my $self = shift;
    my $model = $self->model;
    my $build = $self->build;
#   my $instrument_data = $self->instrument_data;
    my @instrument_data = $model->instrument_data;
    foreach my $data (@instrument_data) {
	my $sff_filename = $data->sff_basename;
	if ($model->read_trimmer_name) {
	    $sff_filename .= '_trimmed';
	}
	$sff_filename .= '.sff';
	unless (-l $build->sff_directory.'/'.$sff_filename) {
	    $self->error_message('Symlink '. $build->sff_directory.'/'.$sff_filename.' not created');
	    return;
	}
    }
#    return $build->sff_directory .'/'. $sff_filename;
    return 1;
}


sub valid_params {
    my $params = {};
    return $params;
}

1;
