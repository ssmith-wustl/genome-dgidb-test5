
package Genome::ProcessingProfile::ImportedVariants;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::ImportedVariants{
    is => 'Genome::ProcessingProfile',
    has => [ ],
};

sub params_for_class {
    my $class = shift;
    return ();
}
