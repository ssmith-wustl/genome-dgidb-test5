package Genome::ProcessingProfile::PolyphredPolyscan;

#:eclark 11/16/2009 Code review.

# Seems like there should better way to define a build that only does one thing.  Implement params_for_class in the base class using introspection.

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::PolyphredPolyscan{
    is => 'Genome::ProcessingProfile::Staged',
    has_param => [
        sensitivity => { },
        research_project => { },
        technology => { },
    ],
};

sub stages {
    return (qw/
            polyphred_polyscan
            verify_successful_completion
            /);
}

sub polyphred_polyscan_job_classes {
    return (qw/
            Genome::Model::Command::Build::PolyphredPolyscan::Run
        /);
}

sub polyphred_polyscan_objects {
    return 1;
}
