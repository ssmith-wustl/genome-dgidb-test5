package Genome::ProcessingProfile::ImportedAssembly;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::ImportedAssembly {
    is => 'Genome::ProcessingProfile',
    has_param => [
        assembler_name => {
            doc => 'Assembler used to generate the assembly',
        },
        assembler_version => {
            is_optional => 1,
            doc => 'Version of the assembler used to generate the assembly',
        },
        assembly_description => {
            is_optional => 1,
            doc => 'Special description of the assembly',
        },
    ],
    doc => "Processing profile to track manually created assemblies",
};

sub _execute_build {
    my ($self, $build) = @_;

    unless (-d $build->data_directory) {
	$self->error_message("Failed to find build directory: ".$build->data_directory);
	return;
    }
    else {
	$self->status_message("Created build directory: ".$build->data_directory);
    }

    return 1;
}

#MORE LATER IF NECESSARY
#sub _validate_assembler {
#    return 1;
#}
#MORE LATER IF NECESSARY
#sub _validate_assembler_version {
#    return 1;
#}

#sub stages {
#    return (qw/ track /);
#}

#sub track_job_classes {
#    return (qw/ Genome::Model::Event::Build::ImportedAssembly /);
#}

#sub objects_for_stage {
#    return (qw/ Genome::Model::Event::Build::ImportedAssembly /);
#}

#sub stages {
#    return (qw/ ImportedAssembly /);
#    return 1;
#}

#sub objects_for_stage {
#    return 1;
#}

#sub classes_for_stage {
#    return 1;
#}

1;

