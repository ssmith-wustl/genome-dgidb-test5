
package Genome::ProcessingProfile::MicrobiomeComposition;

use strict;
use warnings;

use Genome;

class Genome::ProcessingProfile::MicrobiomeComposition {
    is => 'Genome::ProcessingProfile',
    doc => "loosly models the portion of the subject's genome represented by the microbes present in one environmental sample from the organism"
};

sub params_for_class {
    return;
}

1;

