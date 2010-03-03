package Genome::ProcessingProfile::ImportedAssembly;

use strict;
use warnings;
use Genome;

class Genome::ProcessingProfile::ImportedAssembly {
    is => 'Genome::ProcessingProfile',
    has_param => [
        command_name => {
            doc => 'the name of a single command to run',
        },
        args => {
            is_optional => 1,
            doc => 'the arguments to use',
        },
	assembly_description => {
	    doc => 'description of the assembly',
	}
    ],
    doc => "Processing profile to track manually created assemblies",
};

sub stages {
    return (qw/ ImportedAssembly /);
}

1;

