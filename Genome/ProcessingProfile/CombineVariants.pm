package Genome::ProcessingProfile::CombineVariants;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::CombineVariants {
    is => 'Genome::ProcessingProfile::Composite',
};

sub params_for_class{
    return;
}

sub stages {
    return (qw/
             combine_variants
             verify_successful_completion
            /);
}

sub combine_variants_job_classes {
    return (qw/
            Genome::Model::Command::Build::CombineVariants::Run
        /);
}

sub combine_variants_objects {
    return 1;
}

1;
