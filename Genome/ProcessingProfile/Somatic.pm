
package Genome::ProcessingProfile::Somatic;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::Somatic{
    is => 'Genome::ProcessingProfile',
};
sub params_for_class{
    my $self = shift;
    return qw//;
}

sub stages {
    return (qw/
            somatic
            verify_successful_completion
            /);
}

sub somatic_job_classes {
    return (qw/
            Genome::Model::Command::Build::Somatic::RunWorkflow
        /);
}

sub somatic_objects {
    return 1;
}


1;

