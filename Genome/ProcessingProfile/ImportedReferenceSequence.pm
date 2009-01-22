
package Genome::ProcessingProfile::ImportedReferenceSequence;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::ImportedReferenceSequence{
    is => 'Genome::ProcessingProfile',
};

sub stages {
    return (qw/
              imported_reference_sequence
              verify_successful_completion
            /);
}

sub imported_reference_sequence_job_classes {
    return (qw/
            Genome::Model::Command::Build::ImportedReferenceSequence::Run
        /);
}

sub imported_reference_sequence_objects {
    return 1;
}
