package Genome::ProcessingProfile::ManualReview;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::ManualReview {
    is => 'Genome::ProcessingProfile::Composite',
};

sub stages {
    return (qw/
            manual_review
            verify_successful_completion
            /);
}

sub manual_review_job_classes {
    return (qw/
            Genome::Model::Command::Build::ManualReview::Run
        /);
}

sub manual_review_objects {
    return 1;
}

1;
