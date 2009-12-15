package Genome::Model::Event::Build::DeNovoAssembly::Preprocess::Newbler;

use strict;
use warnings;

use Genome;
use Data::Dumper;

class Genome::Model::Event::Build::DeNovoAssembly::Preprocess::Newbler {
    is => 'Genome::Model::Event::Build::DeNovoAssembly::Preprocess',
};

sub execute {
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
