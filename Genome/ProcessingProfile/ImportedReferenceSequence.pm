
package Genome::ProcessingProfile::ImportedReferenceSequence;

#:eclark 11/16/2009 Code review.

# Seems like there should better way to define a build that only does one thing.  Aside from that, this module has no problems (because it does nothing.)

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::ImportedReferenceSequence{
    is => 'Genome::ProcessingProfile::Staged',
};

sub stages {
    return (qw/
              imported_reference_sequence
            /);
}

sub imported_reference_sequence_job_classes {
    return (qw/
            Genome::Model::Event::Build::ImportedReferenceSequence::Run
        /);
}

sub imported_reference_sequence_objects {
    return 1;
}
