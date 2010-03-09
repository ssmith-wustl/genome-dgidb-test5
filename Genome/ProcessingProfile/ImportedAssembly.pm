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

#MORE LATER IF NECESSARY
sub _validate_assembler {
    return 1;
}
#MORE LATER IF NECESSARY
sub _validate_assembler_version {
    return 1;
}

sub stages {
    return (qw/ ImportedAssembly /);
}

1;

