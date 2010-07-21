package Genome::Model::Event::Build::DeNovoAssembly::Assemble::Newbler;

use strict;
use warnings;

use Genome;

class Genome::Model::Event::Build::DeNovoAssembly::Assemble::Newbler {
    is => 'Genome::Model::Event::Build::DeNovoAssembly::Assemble',
};

sub bsub_rusage {
    return "-R 'select[type=LINUX64] rusage[mem=4000]'";
}

sub execute {
    my $self = shift;

    my $model = $self->model;
    my $build = $self->build;

    my $params = $model->assembler_params || '';

    my %run_project_params = (
			      params => $params,
			      dir => $build->data_directory,
			      version => $model->assembler_version,
			      version_subdirectory => $model->version_subdirectory,
			      );

    my $run_project = Genome::Model::Tools::454::Newbler::RunProject->create( %run_project_params );

    unless($run_project->execute) {
        $self->error_message('Failed to run assembly project '. $model->data_directory);
        return;
    }
    my $assembly_dir = $model->data_directory .'/assembly';
    # We set the correct directory permissions when the project is created
    # however, all files and sub-directories are still read-only
    # This must be a newbler default setting...
    # Here we will recursively add group write permissions to every file/directory
    `chmod -R g+w $assembly_dir`;
    return 1;
}

sub valid_params {
    return {
	consed => {
	    is  => 'Boolean',
	    doc => 'Option to generate pcap-like formatted assembly directory',
	},
	vt => {
	    is  => 'String',
	    doc => 'Screening file for .. ',#TODO - NOT SURE WHAT THIS IS SCREENING
	},
	rip => {
	    is => 'Boolean',
	    doc => 'Option to prevent duplication of reads',
	},
    };
}

1;

