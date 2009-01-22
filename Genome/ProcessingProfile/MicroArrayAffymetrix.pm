
package Genome::ProcessingProfile::MicroArrayAffymetrix;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::MicroArrayAffymetrix {
    is => 'Genome::ProcessingProfile::MicroArray',
};

sub params_for_class {
    my $class = shift;
    return $class->SUPER::params_for_class;
}

sub stages {
    return (qw/
            micro_array_affymetrix
            verify_successful_completion
            /);
}

sub micro_array_affymetrix_job_classes {
    return (qw/
            Genome::Model::Command::Build::MicroArrayAffymetrix::Run
        /);
}

sub micro_array_affymetrix_objects {
    return 1;
}
