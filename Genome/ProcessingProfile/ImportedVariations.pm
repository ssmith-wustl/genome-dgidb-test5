package Genome::ProcessingProfile::ImportedVariations;

#:eclark 11/16/2009 Code review.

# Seems like there should better way to define a build that only does one thing.  Aside from that, this module has no problems (because it does nothing.)

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::ImportedVariations {
    is => 'Genome::ProcessingProfile',
};

sub stages {
    return (
        qw/
            import_variations
            verify_successful_completion
            /
    );
}

sub import_variations_job_classes {
    return (
        qw/
            Genome::Model::Command::Build::ImportedVariations::Run
            /
    );
}

sub import_variations_objects {
    return 1;
}
1;
