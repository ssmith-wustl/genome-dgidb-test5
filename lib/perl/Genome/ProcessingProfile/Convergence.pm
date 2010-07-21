package Genome::ProcessingProfile::Convergence;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::Convergence{
    is => 'Genome::ProcessingProfile::Staged',
    has_param => [
    ],
};

sub stages {
    return (qw/
            workflow
            /);
}

sub workflow_job_classes {
    return (qw/
            Genome::Model::Event::Build::Convergence::RunWorkflow
        /);
}

sub workflow_objects {
    return 1;
}


1;

