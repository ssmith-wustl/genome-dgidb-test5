
package Genome::ProcessingProfile::MicroArray;

#:eclark 11/16/2009 Code review.

# Short Term: What is the point of this params_for_class implementation?  Needs to be removed.

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

