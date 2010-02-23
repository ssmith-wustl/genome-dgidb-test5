package Genome::ProcessingProfile::ImportedAssembly;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::ImportedAssembly {
    is => 'Genome::ProcessingProfile::Staged',
    has_param => [
	assembler_name => {
	    doc => 'Name of the assembler used to create the assembly',
	},
    ],
};

1;
