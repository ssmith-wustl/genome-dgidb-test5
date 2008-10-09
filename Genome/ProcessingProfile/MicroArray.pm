
package Genome::ProcessingProfile::MicroArray;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::MicroArray {
    is => 'Genome::ProcessingProfile::ImportedVariants',
};

sub params_for_class {
    my $class = shift;
    return $class->SUPER::params_for_class;
}

1;

