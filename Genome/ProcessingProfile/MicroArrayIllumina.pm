
package Genome::ProcessingProfile::MicroArrayIllumina;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::MicroArrayIllumina {
    is => 'Genome::ProcessingProfile::MicroArray',
};

sub params_for_class {
    my $class = shift;
    return $class->SUPER::params_for_class;
}

sub stages {
    return (qw/
            micro_array_illumina
            verify_successful_completion
            /);
}

sub micro_array_illumina_job_classes {
    return (qw/
            Genome::Model::Command::Build::MicroArrayIllumina::Run
        /);
}

sub micro_array_illumina_objects {
    return 1;
}
