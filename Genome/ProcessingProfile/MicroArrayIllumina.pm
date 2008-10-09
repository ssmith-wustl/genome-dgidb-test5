
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
