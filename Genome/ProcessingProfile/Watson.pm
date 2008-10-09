
package Genome::ProcessingProfile::Watson;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::Watson{
    is => 'Genome::ProcessingProfile::ImportedVariants',
};

sub params_for_class {
    my $class = shift;
    return $class->SUPER::params_for_class;
}
